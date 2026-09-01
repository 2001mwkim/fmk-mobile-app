import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fmk_app/services/app_update_service.dart';

// 앱 업데이트 권장 팝업의 판정 규칙. 네트워크는 MockClient 로 대체한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const body = {
    'android': {'latest': 47, 'minSupported': 40, 'storeUrl': 'https://play/x'},
    'ios': {
      'latest': '0.1.9',
      'minSupported': '0.1.5',
      'storeUrl': 'https://apps/x',
    },
    'message': '새 버전이 나왔어요',
  };

  group('parse', () {
    test('android 섹션을 고르고 latest 는 문자열로 정규화', () {
      final info = AppUpdateInfo.fromJson(body, isIOS: false)!;
      expect(info.latest, '47');
      expect(info.minSupported, '40');
      expect(info.storeUrl, 'https://play/x');
      expect(info.message, '새 버전이 나왔어요');
    });

    test('ios 섹션', () {
      expect(AppUpdateInfo.fromJson(body, isIOS: true)!.latest, '0.1.9');
    });

    test('필수 필드 없으면 null (팝업 안 띄움)', () {
      expect(
        AppUpdateInfo.fromJson({
          'android': {'latest': 47},
        }, isIOS: false),
        isNull,
      );
      expect(AppUpdateInfo.fromJson('garbage', isIOS: false), isNull);
      expect(AppUpdateInfo.fromJson({}, isIOS: false), isNull);
    });
  });

  group('decide', () {
    final info = AppUpdateInfo.fromJson(body, isIOS: false)!;
    test('최신이면 none', () {
      expect(decideAppUpdate(current: '47', info: info), AppUpdateVerdict.none);
      expect(decideAppUpdate(current: '48', info: info), AppUpdateVerdict.none);
    });
    test('낮으면 recommended', () {
      expect(
        decideAppUpdate(current: '46', info: info),
        AppUpdateVerdict.recommended,
      );
    });
    test('minSupported 미만이면 mandatory', () {
      expect(
        decideAppUpdate(current: '39', info: info),
        AppUpdateVerdict.mandatory,
      );
    });
    test('iOS 점 버전 비교', () {
      final ios = AppUpdateInfo.fromJson(body, isIOS: true)!;
      expect(
        decideAppUpdate(current: '0.1.8', info: ios),
        AppUpdateVerdict.recommended,
      );
      expect(decideAppUpdate(current: '0.1.10', info: ios), AppUpdateVerdict.none);
      expect(
        decideAppUpdate(current: '0.1.4', info: ios),
        AppUpdateVerdict.mandatory,
      );
    });
    test('파싱 불가 버전은 업데이트 없음 쪽으로 기운다', () {
      expect(compareAppVersions('abc', '47') < 0, isTrue);
    });
  });

  group('gate', () {
    test('하루 1회만 서버에 묻는다', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = AppUpdateGate(await SharedPreferences.getInstance());
      final now = DateTime(2026, 9, 1, 12);
      expect(gate.shouldCheck(now), isTrue);
      await gate.markChecked(now);
      expect(gate.shouldCheck(now.add(const Duration(hours: 23))), isFalse);
      expect(gate.shouldCheck(now.add(const Duration(hours: 24))), isTrue);
    });

    test('나중에 누른 버전은 권장 팝업을 다시 안 띄우지만 강제는 못 건너뛴다', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = AppUpdateGate(await SharedPreferences.getInstance());
      final info = AppUpdateInfo.fromJson(body, isIOS: false)!;
      expect(gate.isSkipped(info, AppUpdateVerdict.recommended), isFalse);
      await gate.skip(info);
      expect(gate.isSkipped(info, AppUpdateVerdict.recommended), isTrue);
      expect(gate.isSkipped(info, AppUpdateVerdict.mandatory), isFalse);
      // 더 새 버전이 나오면 다시 묻는다.
      const newer = AppUpdateInfo(
        latest: '48',
        minSupported: '',
        storeUrl: 'u',
        message: 'm',
      );
      expect(gate.isSkipped(newer, AppUpdateVerdict.recommended), isFalse);
    });
  });

  group('fetch', () {
    test('200 이면 파싱, 그 외/예외는 null', () async {
      final ok = AppUpdateService(
        url: 'https://x/app-version.json',
        isIOS: false,
        client: MockClient(
          // 실제 서버처럼 charset=utf-8 — 없으면 http 가 latin1 로 인코딩해 한글에서 예외.
          (_) async => http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      expect((await ok.fetch())!.latest, '47');

      final bad = AppUpdateService(
        url: 'https://x/app-version.json',
        isIOS: false,
        client: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(await bad.fetch(), isNull);

      final boom = AppUpdateService(
        url: 'https://x/app-version.json',
        isIOS: false,
        client: MockClient((_) async => throw Exception('net')),
      );
      expect(await boom.fetch(), isNull);
    });
  });
}
