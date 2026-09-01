import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';

/// 앱 업데이트 권장 팝업용 버전 파일 endpoint.
///
/// collector(fmk-f1-calendar `data/app-version.json`)가 `/app-version.json` 으로
/// 서빙하고 Cloudflare 가 5분 캐시한다 — 라이브와 같은 호스트라 Vercel 을 타지
/// 않고, 하루 1회 체크라 origin 부하도 없다. 갱신은 스토어 심사 통과 **후**에
/// `npm run app-version -- android 47` 로 사람이 올린다(자동이 아니다).
const bool _kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');
const String kAppVersionUrl = String.fromEnvironment(
  'APP_VERSION_URL',
  defaultValue: _kIsReleaseBuild
      ? 'https://live.formulamagazine.kr/app-version.json'
      : 'http://localhost:8787/app-version.json',
);

/// 하루에 한 번만 서버에 물어본다. 더 자주 물어봐도 파일은 사람이 올릴 때만
/// 바뀌므로 의미가 없고, 앱 시작마다 네트워크를 태우지 않으려는 것.
const Duration kAppUpdateCheckInterval = Duration(hours: 24);

const String appUpdateLastCheckPrefsKey = 'app_update_last_check_ms';
const String appUpdateSkippedPrefsKey = 'app_update_skipped';

/// 서버가 내려준 현재 플랫폼의 버전 정보.
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latest,
    required this.minSupported,
    required this.storeUrl,
    required this.message,
  });

  /// 스토어에 올라간 최신 버전. Android 는 빌드 번호("47"), iOS 는 "0.1.9".
  final String latest;

  /// 이보다 낮으면 강제 업데이트(닫을 수 없는 팝업). 비어 있으면 강제 없음.
  final String minSupported;
  final String storeUrl;
  final String message;

  /// `{ android: {...}, ios: {...}, message }` 에서 플랫폼 섹션을 고른다.
  /// 필수 필드가 없으면 null — 팝업을 띄우지 않는 쪽이 안전하다.
  static AppUpdateInfo? fromJson(Object? body, {required bool isIOS}) {
    if (body is! Map) return null;
    final section = body[isIOS ? 'ios' : 'android'];
    if (section is! Map) return null;
    final latest = section['latest'];
    final storeUrl = section['storeUrl'];
    if (latest == null || storeUrl is! String || storeUrl.isEmpty) return null;
    final message = body['message'];
    return AppUpdateInfo(
      latest: latest.toString(),
      minSupported: (section['minSupported'] ?? '').toString(),
      storeUrl: storeUrl,
      message: message is String && message.trim().isNotEmpty
          ? message
          : '새 버전이 나왔어요. 업데이트해 주세요.',
    );
  }
}

enum AppUpdateVerdict {
  /// 최신이거나 비교 불가 — 아무것도 안 띄운다.
  none,

  /// 새 버전 있음 — "나중에" 가능한 권장 팝업.
  recommended,

  /// minSupported 미만 — 닫을 수 없는 강제 팝업.
  mandatory,
}

/// 버전 문자열 비교. Android 는 정수 빌드 번호, iOS 는 "0.1.9" 꼴.
/// 파싱 실패는 0 으로 취급해 "업데이트 없음" 쪽으로 기운다.
int compareAppVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

AppUpdateVerdict decideAppUpdate({
  required String current,
  required AppUpdateInfo info,
}) {
  if (info.minSupported.isNotEmpty &&
      compareAppVersions(current, info.minSupported) < 0) {
    return AppUpdateVerdict.mandatory;
  }
  if (compareAppVersions(current, info.latest) < 0) {
    return AppUpdateVerdict.recommended;
  }
  return AppUpdateVerdict.none;
}

/// 팝업을 띄울지 최종 판단. 서버 fetch 는 [AppUpdateService] 가, 이 클래스는
/// "하루 1회" 와 "나중에 누른 버전은 다시 안 묻기" 규칙만 담당한다(테스트 용이).
class AppUpdateGate {
  const AppUpdateGate(this.prefs);

  final SharedPreferences prefs;

  /// 오늘 이미 확인했으면 서버에 물어보지 않는다. 강제 업데이트 후보라도 마찬가지
  /// — 어차피 하루 안에는 파일이 바뀌지 않는다.
  bool shouldCheck(DateTime now) {
    final last = prefs.getInt(appUpdateLastCheckPrefsKey);
    if (last == null) return true;
    return now.difference(DateTime.fromMillisecondsSinceEpoch(last)) >=
        kAppUpdateCheckInterval;
  }

  Future<void> markChecked(DateTime now) =>
      prefs.setInt(appUpdateLastCheckPrefsKey, now.millisecondsSinceEpoch);

  /// "나중에"를 누른 버전이면 권장 팝업은 다시 띄우지 않는다. 강제([mandatory])는
  /// 건너뛸 수 없다.
  bool isSkipped(AppUpdateInfo info, AppUpdateVerdict verdict) {
    if (verdict == AppUpdateVerdict.mandatory) return false;
    return prefs.getString(appUpdateSkippedPrefsKey) == info.latest;
  }

  Future<void> skip(AppUpdateInfo info) =>
      prefs.setString(appUpdateSkippedPrefsKey, info.latest);
}

/// app-version.json 을 받아 [AppUpdateInfo] 로 파싱한다. 실패는 null(팝업 없음).
class AppUpdateService {
  const AppUpdateService({this.url = kAppVersionUrl, this.client, this.isIOS});

  final String url;
  final http.Client? client;

  /// 테스트 주입용. null 이면 실행 플랫폼으로 판단.
  final bool? isIOS;

  bool get _isIOS =>
      isIOS ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  Future<AppUpdateInfo?> fetch() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return AppUpdateInfo.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true)),
        isIOS: _isIOS,
      );
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// 현재 앱 버전 문자열 — Android 는 빌드 번호, iOS 는 버전명(서버 파일과 같은 기준).
  String get currentVersion => _isIOS ? kAppVersion : kAppBuildNumber;
}
