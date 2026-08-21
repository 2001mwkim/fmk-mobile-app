import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/country_flags.dart';
import '../data/drivers.dart';
import '../data/races.dart';
import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../data/teams.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../models/standing.dart';
import 'live_session_controller.dart';
import 'live_session_service.dart';
import 'my_picks_controller.dart';
import 'race_results_repository.dart';
import 'standings_repository.dart';

const String fmkHomeWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkHomeWidgetProvider';

/// 챔피언십 순위 위젯(별도 위젯 종류)의 Provider.
const String fmkStandingsWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkStandingsWidgetProvider';

/// MY DRIVER / MY TEAM 위젯(각각 별도 위젯 종류)의 Provider.
const String fmkMyDriverWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkMyDriverWidgetProvider';
const String fmkMyTeamWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkMyTeamWidgetProvider';

/// iOS App Group — Runner/FmkWidgets 익스텐션 entitlements 와 문자열로
/// 수동 동기화(ios/Runner/Runner.entitlements, ios/FmkWidgets/*.entitlements).
const String fmkWidgetAppGroupId = 'group.kr.formulamagazine.fmk';

/// iOS WidgetKit kind 문자열 — ios/FmkWidgets/ 의 Widget kind 와 수동 동기화.
/// iOS 는 토글 대신 종류를 나눈다(드라이버/팀 순위가 각각 별도 위젯).
const String fmkHomeWidgetIOSKind = 'FmkHomeWidget';
const String fmkDriverStandingsWidgetIOSKind = 'FmkDriverStandingsWidget';
const String fmkTeamStandingsWidgetIOSKind = 'FmkTeamStandingsWidget';
const String fmkMyDriverWidgetIOSKind = 'FmkMyDriverWidget';
const String fmkMyTeamWidgetIOSKind = 'FmkMyTeamWidget';

/// 위젯 탭 딥링크 URI(fmkwidget://…) → 하단 탭 인덱스.
/// 인덱스는 app.dart 의 MainShell._screens / BottomNav._items 순서와 1:1
/// (홈 0 · 일정 1 · 순위 2 · 라이브 3). URI 는 Kotlin Provider 들이 만든다.
int? fmkWidgetTabIndexForUri(Uri? uri) {
  if (uri == null || uri.scheme != 'fmkwidget') return null;
  return switch (uri.host) {
    'home' => 0,
    'standings' => 2,
    'live' => 3,
    _ => null,
  };
}

/// MY DRIVER/MY TEAM 위젯 탭(fmkwidget://mypicks) — 탭 전환이 아니라 설정
/// 화면(MY PICKS 섹션)을 연다. 미설정 상태의 위젯이 "앱에서 설정" 안내를
/// 띄우므로, 탭 한 번에 선택기까지 닿아야 한다.
bool fmkWidgetOpensMyPicks(Uri? uri) =>
    uri != null && uri.scheme == 'fmkwidget' && uri.host == 'mypicks';

const String _modeDefault = 'default';
const String _modeLive = 'live';

/// 라이브가 없을 때 우측 화면에 최근 확정 결과를 보여주는 모드.
const String _modeResult = 'result';

class FmkHomeWidgetPayload {
  const FmkHomeWidgetPayload({
    required this.mode,
    required this.gpFlag,
    required this.gpName,
    required this.scheduleGpFlag,
    required this.scheduleGpName,
    this.scheduleRaceId = '',
    required this.sessions,
    required this.sessionHighlightIndex,
    required this.liveBadge,
    required this.lapCurrent,
    required this.lapTotal,
    required this.topThree,
    required this.topThreePositions,
    required this.topThreeNames,
    required this.topThreeTimes,
    required this.topThreeColors,
  });

  final String mode;
  final String gpFlag;
  final String gpName;

  /// 위젯 토글용 일정 화면 헤더. live 모드에서도 항상 채워서, 위젯이 앱 실행
  /// 없이 라이브 ↔ 일정 화면을 전환할 수 있게 한다.
  final String scheduleGpFlag;
  final String scheduleGpName;

  /// 일정 화면 그랑프리의 races.dart id. iOS 위젯이 라이브 스냅샷의 raceId 와
  /// 대조해 '다음 세션 30분 전까지 노출' 규칙을 적용할 때 쓴다(Android 미사용).
  final String scheduleRaceId;

  /// 다음 그랑프리 세션 일정(최대 5개). 모드와 무관하게 항상 채운다.
  final List<FmkHomeWidgetSessionRow> sessions;

  /// 아직 시작 전인 첫 세션(1-based). 0이면 하이라이트 없음(주말 종료 등).
  /// 위젯이 이 행에 레드 도트를 찍고 지난 세션을 가라앉힌다.
  final int sessionHighlightIndex;
  final String liveBadge;
  final int lapCurrent;
  final int lapTotal;
  final List<String> topThree;
  final List<int> topThreePositions;
  final List<String> topThreeNames;
  final List<String> topThreeTimes;
  final List<int> topThreeColors;

  bool get isLive => mode == _modeLive;
  bool get isResult => mode == _modeResult;
}

class FmkHomeWidgetSessionRow {
  const FmkHomeWidgetSessionRow({
    required this.name,
    required this.date,
    required this.time,
    this.id = '',
    this.startEpochMs = 0,
    this.endEpochMs = 0,
  });

  final String name;
  final String date;
  final String time;

  /// races.dart 의 세션 id('fp1'/'qualifying'/'race' 등). iOS 위젯 타임라인이
  /// 세션 경계 전환·퀄리 세그먼트 보정에 쓴다(Android 위젯은 무시).
  final String id;

  /// 세션 시작/종료(UTC epoch millis). 0 이면 정보 없음.
  final int startEpochMs;
  final int endEpochMs;
}

class FmkHomeWidgetBridge {
  const FmkHomeWidgetBridge._();

  static bool _bound = false;

  /// 홈 위젯 지원 플랫폼(Android 위젯 + iOS WidgetKit).
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool _appGroupConfigured = false;

  /// iOS 는 저장 전에 App Group 지정이 필수(플러그인이 UserDefaults suite 로
  /// 기록). Android 에서는 no-op 이지만 분기 없이 한 번만 호출해 둔다.
  static Future<void> _ensureAppGroup() async {
    if (_appGroupConfigured || !_isIOS) return;
    _appGroupConfigured = true;
    await HomeWidget.setAppGroupId(fmkWidgetAppGroupId);
  }

  /// 최근 확정 결과 캐시 — 라이브가 없을 때 위젯 '결과' 화면의 데이터.
  /// 확정 결과는 레이스 후 바뀌지 않으므로 낡아도 틀리지 않는다.
  static LatestRaceResult? _latestResult;
  static DateTime? _latestResultFetchedAt;

  /// 테스트 주입 지점(기본은 실서버 /api/race-results).
  @visibleForTesting
  static RaceResultsRepository resultsRepository =
      const HttpRaceResultsRepository();

  /// 챔피언십 순위 캐시 — 순위 위젯 데이터. 서버 실패 시 번들 정적 순위 사용.
  static StandingsSnapshot? _standings;
  static DateTime? _standingsFetchedAt;

  /// 테스트 주입 지점(기본은 실서버 /api/standings).
  @visibleForTesting
  static StandingsRepository standingsRepository =
      const HttpStandingsRepository();

  static void bindTo(LiveSessionController controller) {
    if (_bound) return;
    _bound = true;
    controller.addListener(() {
      unawaited(update(snapshot: controller.snapshot));
    });
  }

  /// 확정 결과를 (최대 30분에 한 번) 갱신한다. 실패는 무시 — 기존 캐시 유지.
  static Future<void> _ensureLatestResult({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _latestResultFetchedAt != null &&
        now.difference(_latestResultFetchedAt!) < const Duration(minutes: 30)) {
      return;
    }
    _latestResultFetchedAt = now;
    try {
      _latestResult = await resultsRepository.fetchLatest() ?? _latestResult;
    } catch (_) {
      // 네트워크 실패 → 기존 캐시 유지(없으면 일정 전용 모드로 렌더).
    }
  }

  /// 챔피언십 순위 갱신(최대 6시간에 한 번 — 서버 갱신 주기와 동일).
  /// 실패는 무시: 기존 캐시, 그것도 없으면 번들 정적 순위로 그린다.
  static Future<void> _ensureStandings() async {
    final now = DateTime.now();
    if (_standingsFetchedAt != null &&
        now.difference(_standingsFetchedAt!) < const Duration(hours: 6)) {
      return;
    }
    _standingsFetchedAt = now;
    try {
      _standings = await standingsRepository.fetchLatest() ?? _standings;
    } catch (_) {
      // 유지.
    }
  }

  static Future<void> update({
    LiveSessionSnapshot? snapshot,
    DateTime? now,
  }) async {
    if (!_supported) return;

    await _ensureLatestResult();
    await _ensureStandings();
    final payload = buildFmkHomeWidgetPayload(
      snapshot: snapshot,
      latestResult: _latestResult,
      now: now,
    );

    try {
      await _ensureAppGroup();
      await _savePayload(payload);
      await _saveStandingsPayload(_standings);
      await _saveMyPicksPayload(_standings);
      if (_isIOS) await _saveIOSExtras();
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkHomeWidgetProviderQualifiedName,
        iOSName: fmkHomeWidgetIOSKind,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkStandingsWidgetProviderQualifiedName,
        iOSName: fmkDriverStandingsWidgetIOSKind,
      );
      if (_isIOS) {
        await HomeWidget.updateWidget(iOSName: fmkTeamStandingsWidgetIOSKind);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkMyDriverWidgetProviderQualifiedName,
        iOSName: fmkMyDriverWidgetIOSKind,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkMyTeamWidgetProviderQualifiedName,
        iOSName: fmkMyTeamWidgetIOSKind,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update Fmk home widget: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 사용자가 고른 위젯 팔레트(dark/light/system)를 네이티브 위젯 저장소에
  /// 기록하고 모든 위젯을 즉시 갱신한다. 값은 Android FmkWidgetTheme.kt·iOS
  /// FmkTheme.swift 에서 'widgetThemeMode' 키로 동일하게 읽는다.
  static Future<void> updateTheme(String mode) async {
    if (!_supported) return;
    try {
      await _ensureAppGroup();
      await HomeWidget.saveWidgetData<String>('widgetThemeMode', mode);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkHomeWidgetProviderQualifiedName,
        iOSName: fmkHomeWidgetIOSKind,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkStandingsWidgetProviderQualifiedName,
        iOSName: fmkDriverStandingsWidgetIOSKind,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkMyDriverWidgetProviderQualifiedName,
        iOSName: fmkMyDriverWidgetIOSKind,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkMyTeamWidgetProviderQualifiedName,
        iOSName: fmkMyTeamWidgetIOSKind,
      );
      if (_isIOS) {
        await HomeWidget.updateWidget(iOSName: fmkTeamStandingsWidgetIOSKind);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to update widget theme: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// iOS 위젯 전용 보조 데이터. 위젯 익스텐션이 live.json 을 직접 fetch 할 때
  /// 필요한 것들을 앱(Dart)이 단일 출처로 내려보낸다:
  /// 드라이버 한글 이름/팀 액센트(drivers.dart), fetch URL(dart-define 반영).
  static Future<void> _saveIOSExtras() async {
    final names = <String, String>{...driverNameKoByCode};
    final accents = <String, int>{
      for (final code in driverNameKoByCode.keys)
        code: liveDriverAccent(code).toARGB32(),
    };
    await Future.wait<bool?>([
      HomeWidget.saveWidgetData<String>('driverNamesKoJson', jsonEncode(names)),
      HomeWidget.saveWidgetData<String>(
        'driverAccentsJson',
        jsonEncode(accents),
      ),
      HomeWidget.saveWidgetData<String>('liveJsonUrl', kLiveJsonUrl),
    ]);
  }

  /// 앱이 위젯 탭으로 "시작"됐을 때의 딥링크 URI. 아니거나 실패하면 null
  /// (테스트/플러그인 미등록 환경 포함 — 절대 던지지 않는다).
  static Future<Uri?> initialLaunchUri() async {
    if (!_supported) return null;
    try {
      await _ensureAppGroup();
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  /// 앱 "실행 중" 위젯 탭 딥링크 스트림. 미지원 플랫폼이면 빈 스트림.
  /// 채널 오류는 구독부에서 onError 로 무시할 것(테스트 환경 대비).
  static Stream<Uri?> widgetClicks() {
    if (!_supported) return const Stream<Uri?>.empty();
    return HomeWidget.widgetClicked;
  }

  /// 런처에 위젯 고정(pin) 다이얼로그를 요청한다. 다이얼로그를 띄웠으면 true,
  /// 미지원 런처/플랫폼이면 false — 호출부가 수동 추가 안내를 띄운다.
  /// [qualifiedAndroidName]으로 위젯 종류(메인/순위)를 고른다.
  static Future<bool> requestPinWidget({
    String qualifiedAndroidName = fmkHomeWidgetProviderQualifiedName,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: qualifiedAndroidName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 백그라운드(WorkManager)에서 호출 — 앱이 실행 중이 아니어도 라이브
  /// 스냅샷과 확정 결과를 직접 받아 위젯 데이터를 갱신한다.
  static Future<void> refreshFromNetwork() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    LiveSessionSnapshot? snapshot;
    try {
      snapshot = await LiveSessionService().fetch();
    } catch (_) {
      snapshot = null; // 라이브 실패 → 일정/결과 화면만 갱신.
    }
    await _ensureLatestResult(force: true);
    await update(snapshot: snapshot);
  }

  static Future<void> _savePayload(FmkHomeWidgetPayload payload) async {
    final writes = <Future<bool?>>[
      HomeWidget.saveWidgetData<String>('mode', payload.mode),
      HomeWidget.saveWidgetData<String>('gpFlag', payload.gpFlag),
      HomeWidget.saveWidgetData<String>('gpName', payload.gpName),
      HomeWidget.saveWidgetData<String>(
        'scheduleGpFlag',
        payload.scheduleGpFlag,
      ),
      HomeWidget.saveWidgetData<String>(
        'scheduleGpName',
        payload.scheduleGpName,
      ),
      // iOS 위젯의 라이브 노출 기한 판정용(Android 미사용).
      HomeWidget.saveWidgetData<String>(
        'scheduleRaceId',
        payload.scheduleRaceId,
      ),
      HomeWidget.saveWidgetData<String>('liveBadge', payload.liveBadge),
      HomeWidget.saveWidgetData<int>('lapCurrent', payload.lapCurrent),
      HomeWidget.saveWidgetData<int>('lapTotal', payload.lapTotal),
      HomeWidget.saveWidgetData<int>(
        'sessionHighlightIndex',
        payload.sessionHighlightIndex,
      ),
    ];

    for (var i = 0; i < 5; i++) {
      final session = i < payload.sessions.length ? payload.sessions[i] : null;
      final index = i + 1;
      writes.addAll([
        HomeWidget.saveWidgetData<String>(
          'session${index}Name',
          session?.name ?? '',
        ),
        HomeWidget.saveWidgetData<String>(
          'session${index}Date',
          session?.date ?? '',
        ),
        HomeWidget.saveWidgetData<String>(
          'session${index}Time',
          session?.time ?? '',
        ),
        HomeWidget.saveWidgetData<int>(
          'session${index}Visible',
          session == null ? 0 : 1,
        ),
        // iOS 위젯 타임라인용(세션 경계 자동 전환·라이브 창 판정).
        HomeWidget.saveWidgetData<String>(
          'session${index}Id',
          session?.id ?? '',
        ),
        HomeWidget.saveWidgetData<int>(
          'session${index}StartEpoch',
          session?.startEpochMs ?? 0,
        ),
        HomeWidget.saveWidgetData<int>(
          'session${index}EndEpoch',
          session?.endEpochMs ?? 0,
        ),
      ]);
    }

    for (var i = 0; i < 3; i++) {
      writes.addAll([
        HomeWidget.saveWidgetData<String>(
          'p${i + 1}Code',
          i < payload.topThree.length ? payload.topThree[i] : '',
        ),
        HomeWidget.saveWidgetData<int>(
          'p${i + 1}Position',
          i < payload.topThreePositions.length
              ? payload.topThreePositions[i]
              : i + 1,
        ),
        HomeWidget.saveWidgetData<String>(
          'p${i + 1}Name',
          i < payload.topThreeNames.length ? payload.topThreeNames[i] : '',
        ),
        HomeWidget.saveWidgetData<String>(
          'p${i + 1}Time',
          i < payload.topThreeTimes.length ? payload.topThreeTimes[i] : '',
        ),
        HomeWidget.saveWidgetData<int>(
          'p${i + 1}Color',
          i < payload.topThreeColors.length
              ? payload.topThreeColors[i]
              : _androidColorInt(0xFFEF4444),
        ),
      ]);
    }

    await Future.wait(writes);
  }

  /// 순위 위젯 데이터 저장. 서버 순위가 없으면 번들 정적 순위(초기값)로
  /// 채워서, 위젯을 추가한 직후에도 빈 화면이 나오지 않게 한다.
  static Future<void> _saveStandingsPayload(StandingsSnapshot? snapshot) async {
    final drivers = buildFmkStandingsWidgetRows(
      driverStandings:
          snapshot?.driverStandings ?? static_standings.driverStandings,
    );
    final teams = buildFmkStandingsWidgetRows(
      constructorStandings:
          snapshot?.constructorStandings ??
          static_standings.constructorStandings,
    );

    final writes = <Future<bool?>>[];
    void writeRows(String prefix, List<FmkStandingsWidgetRow> rows) {
      for (var i = 0; i < 5; i++) {
        final row = i < rows.length ? rows[i] : null;
        final key = '$prefix${i + 1}';
        writes.addAll([
          HomeWidget.saveWidgetData<int>('${key}Visible', row == null ? 0 : 1),
          HomeWidget.saveWidgetData<int>('${key}Pos', row?.position ?? i + 1),
          HomeWidget.saveWidgetData<String>('${key}Name', row?.name ?? ''),
          HomeWidget.saveWidgetData<String>('${key}Pts', row?.points ?? ''),
          HomeWidget.saveWidgetData<String>(
            '${key}Change',
            row?.changeLabel ?? '',
          ),
          HomeWidget.saveWidgetData<int>(
            '${key}ChangeColor',
            _androidColorInt(row?.changeColor ?? 0xFF7880A0),
          ),
          HomeWidget.saveWidgetData<int>(
            '${key}Color',
            _androidColorInt(row?.teamColor ?? 0xFFEF4444),
          ),
        ]);
      }
    }

    writeRows('stDriver', drivers);
    writeRows('stTeam', teams);
    await Future.wait(writes);
  }

  /// MY DRIVER / MY TEAM 위젯 데이터(myDriver*/myTeam* 키). 저장된 선택
  /// (my_picks_controller)을 순위 행과 이어 붙인다. 키는 Kotlin
  /// (FmkMyDriverWidgetProvider/FmkMyTeamWidgetProvider)·Swift
  /// (FmkMyPicksWidgets.swift)와 수동 동기화 — 한쪽을 바꾸면 함께 수정할 것.
  static Future<void> _saveMyPicksPayload(StandingsSnapshot? snapshot) async {
    final picks = await myPicksController.load();
    final payload = buildFmkMyPicksPayload(
      picks: picks,
      driverStandings:
          snapshot?.driverStandings ?? static_standings.driverStandings,
      constructorStandings:
          snapshot?.constructorStandings ??
          static_standings.constructorStandings,
    );
    final d = payload.driver;
    final t = payload.team;
    await Future.wait<bool?>([
      // ── MY DRIVER ──
      // set: 골랐는지(0 → 위젯이 "앱에서 설정" 안내), found: 순위에 있는지
      // (0 → 이름/팀만, 순위·포인트는 '—').
      HomeWidget.saveWidgetData<int>('myDriverSet', d == null ? 0 : 1),
      HomeWidget.saveWidgetData<int>('myDriverFound', d?.found == true ? 1 : 0),
      HomeWidget.saveWidgetData<String>('myDriverCode', d?.code ?? ''),
      HomeWidget.saveWidgetData<String>('myDriverNameEn', d?.nameEn ?? ''),
      HomeWidget.saveWidgetData<String>('myDriverNameKo', d?.nameKo ?? ''),
      HomeWidget.saveWidgetData<String>('myDriverTeamKo', d?.teamKo ?? ''),
      HomeWidget.saveWidgetData<String>('myDriverTeamEn', d?.teamEn ?? ''),
      HomeWidget.saveWidgetData<int>('myDriverPos', d?.position ?? 0),
      HomeWidget.saveWidgetData<String>('myDriverPts', d?.points ?? ''),
      HomeWidget.saveWidgetData<String>('myDriverGap', d?.gapToLeader ?? ''),
      HomeWidget.saveWidgetData<String>(
        'myDriverChange',
        d?.changeLabel ?? '',
      ),
      HomeWidget.saveWidgetData<int>(
        'myDriverChangeColor',
        _androidColorInt(d?.changeColor ?? 0xFF7880A0),
      ),
      HomeWidget.saveWidgetData<int>(
        'myDriverColor',
        _androidColorInt(d?.teamColor ?? 0xFFEF4444),
      ),
      // ── MY TEAM ──
      HomeWidget.saveWidgetData<int>('myTeamSet', t == null ? 0 : 1),
      HomeWidget.saveWidgetData<int>('myTeamFound', t?.found == true ? 1 : 0),
      HomeWidget.saveWidgetData<String>('myTeamKo', t?.teamKo ?? ''),
      HomeWidget.saveWidgetData<String>('myTeamEn', t?.teamEn ?? ''),
      HomeWidget.saveWidgetData<String>('myTeamCode', t?.code ?? ''),
      HomeWidget.saveWidgetData<int>('myTeamPos', t?.position ?? 0),
      HomeWidget.saveWidgetData<String>('myTeamPts', t?.points ?? ''),
      HomeWidget.saveWidgetData<String>('myTeamGap', t?.gapToLeader ?? ''),
      HomeWidget.saveWidgetData<String>('myTeamChange', t?.changeLabel ?? ''),
      HomeWidget.saveWidgetData<int>(
        'myTeamChangeColor',
        _androidColorInt(t?.changeColor ?? 0xFF7880A0),
      ),
      HomeWidget.saveWidgetData<int>(
        'myTeamColor',
        _androidColorInt(t?.teamColor ?? 0xFFEF4444),
      ),
      // 팀 소속 드라이버 2명(순위순) — 팀 위젯 medium 의 보조 행.
      for (var i = 0; i < 2; i++) ...[
        HomeWidget.saveWidgetData<String>(
          'myTeamD${i + 1}Code',
          t != null && i < t.drivers.length ? t.drivers[i].code : '',
        ),
        HomeWidget.saveWidgetData<int>(
          'myTeamD${i + 1}Pos',
          t != null && i < t.drivers.length ? t.drivers[i].position : 0,
        ),
        HomeWidget.saveWidgetData<String>(
          'myTeamD${i + 1}Pts',
          t != null && i < t.drivers.length ? t.drivers[i].points : '',
        ),
      ],
    ]);
  }
}

/// MY DRIVER 위젯 한 장의 표시 데이터.
class FmkMyDriverWidgetData {
  const FmkMyDriverWidgetData({
    required this.code,
    required this.nameEn,
    required this.nameKo,
    required this.teamKo,
    required this.teamEn,
    required this.teamColor,
    required this.found,
    this.position = 0,
    this.points = '',
    this.gapToLeader = '',
    this.changeLabel = '',
    this.changeColor = 0xFF7880A0,
  });

  final String code;
  final String nameEn;
  final String nameKo;
  final String teamKo;
  final String teamEn;
  final int teamColor;

  /// 순위 데이터에서 찾았는지. false 면 이름/팀만 유효(순위·포인트 '—').
  final bool found;
  final int position;
  final String points;

  /// 선두와의 포인트 차. 선두면 'LEADER', 모르면 빈 문자열, 그 외 '-41' 형식.
  final String gapToLeader;
  final String changeLabel;
  final int changeColor;
}

/// MY TEAM 위젯 소속 드라이버 한 줄.
class FmkMyTeamDriverData {
  const FmkMyTeamDriverData({
    required this.code,
    required this.position,
    required this.points,
  });

  final String code;
  final int position;
  final String points;
}

/// MY TEAM 위젯 한 장의 표시 데이터.
class FmkMyTeamWidgetData {
  const FmkMyTeamWidgetData({
    required this.teamKo,
    required this.teamEn,
    required this.code,
    required this.teamColor,
    required this.found,
    this.position = 0,
    this.points = '',
    this.gapToLeader = '',
    this.changeLabel = '',
    this.changeColor = 0xFF7880A0,
    this.drivers = const [],
  });

  final String teamKo;
  final String teamEn;
  final String code;
  final int teamColor;
  final bool found;
  final int position;
  final String points;
  final String gapToLeader;
  final String changeLabel;
  final int changeColor;

  /// 소속 드라이버(순위순, 최대 2명).
  final List<FmkMyTeamDriverData> drivers;
}

/// MY PICKS 위젯 페이로드. 미설정 항목은 null(위젯이 안내 문구 표시).
class FmkMyPicksPayload {
  const FmkMyPicksPayload({this.driver, this.team});

  final FmkMyDriverWidgetData? driver;
  final FmkMyTeamWidgetData? team;
}

/// 저장된 선택([picks])을 순위 데이터와 결합해 위젯 페이로드를 만든다.
/// 순수 함수 — 서버 순위가 없으면 호출부가 정적 순위를 넘긴다.
FmkMyPicksPayload buildFmkMyPicksPayload({
  required MyPicks picks,
  required List<DriverStanding> driverStandings,
  required List<ConstructorStanding> constructorStandings,
}) {
  FmkMyDriverWidgetData? driver;
  if (picks.hasDriver) {
    final code = picks.driverCode!.trim().toUpperCase();
    final nameKo = driverNameKoByCode[code];
    DriverStanding? row;
    for (final d in driverStandings) {
      if (nameKo != null && d.driverKo == nameKo) {
        row = d;
        break;
      }
    }
    // 한글 이름 매핑이 없으면(신인 등) 서버 영문 이름의 성(lastName)으로 한 번 더.
    if (row == null && nameKo == null) {
      for (final d in driverStandings) {
        final en = d.driverEn.trim().toUpperCase();
        if (en.isNotEmpty && _lastNameCode(en) == code) {
          row = d;
          break;
        }
      }
    }
    final leaderPoints = driverStandings.isEmpty
        ? null
        : driverStandings.first.points;
    final change = _changeStyle(row?.positionChange);
    final teamKo = row?.teamKo ?? '';
    driver = FmkMyDriverWidgetData(
      code: code,
      nameEn: driverNameEn(code, row?.driverEn ?? code),
      nameKo: nameKo ?? row?.driverKo ?? code,
      teamKo: teamKo,
      teamEn: teamNameEn(teamKo, row?.teamEn ?? ''),
      teamColor: row != null
          ? getTeamColorHex(row.teamKo)
          : liveDriverAccent(code).toARGB32(),
      found: row != null,
      position: row?.position ?? 0,
      points: row == null ? '' : _formatWidgetPoints(row.points),
      gapToLeader: row == null || leaderPoints == null
          ? ''
          : _gapLabel(row.position, row.points, leaderPoints),
      changeLabel: change.label,
      changeColor: change.color,
    );
  }

  FmkMyTeamWidgetData? team;
  if (picks.hasTeam) {
    final teamKo = picks.teamKo!.trim();
    ConstructorStanding? row;
    for (final c in constructorStandings) {
      if (c.teamKo == teamKo) {
        row = c;
        break;
      }
    }
    final leaderPoints = constructorStandings.isEmpty
        ? null
        : constructorStandings.first.points;
    final change = _changeStyle(row?.positionChange);
    final members = [
      for (final d in driverStandings)
        if (d.teamKo == teamKo)
          FmkMyTeamDriverData(
            code: driverCodeByNameKo[d.driverKo] ?? _lastNameCode(d.driverEn),
            position: d.position,
            points: _formatWidgetPoints(d.points),
          ),
    ]..sort((a, b) => a.position.compareTo(b.position));
    team = FmkMyTeamWidgetData(
      teamKo: teamKo,
      teamEn: teamNameEn(teamKo, row?.teamEn ?? teamKo),
      code: teamCode(teamKo, fallbackEn: row?.teamEn ?? ''),
      teamColor: getTeamColorHex(teamKo),
      found: row != null,
      position: row?.position ?? 0,
      points: row == null ? '' : _formatWidgetPoints(row.points),
      gapToLeader: row == null || leaderPoints == null
          ? ''
          : _gapLabel(row.position, row.points, leaderPoints),
      changeLabel: change.label,
      changeColor: change.color,
      drivers: members.take(2).toList(),
    );
  }

  return FmkMyPicksPayload(driver: driver, team: team);
}

/// 순위 탭 _PositionChange 와 같은 규칙/색(green/redSoft/muted).
({String label, int color}) _changeStyle(int? change) {
  if (change == null) return (label: '', color: 0xFF7880A0);
  if (change > 0) return (label: '▲$change', color: 0xFF4ADE80);
  if (change < 0) return (label: '▼${change.abs()}', color: 0xFFF87171);
  return (label: '—', color: 0xFF7880A0);
}

/// 선두와의 격차 라벨: 1위는 'LEADER', 그 외 '-41'(소수점 포인트는 그대로).
String _gapLabel(int position, num points, num leaderPoints) {
  if (position == 1) return 'LEADER';
  final gap = leaderPoints - points;
  if (gap <= 0) return 'LEADER';
  return '-${_formatWidgetPoints(gap)}';
}

/// 영문 이름의 성 앞 3글자(대문자) — 코드 매핑이 없을 때의 임시 TLA.
String _lastNameCode(String nameEn) {
  final parts = nameEn
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && !p.endsWith('.'))
      .toList();
  if (parts.isEmpty) return '';
  final last = parts.last.toUpperCase();
  return last.length <= 3 ? last : last.substring(0, 3);
}

/// 순위 위젯 한 행의 표시 데이터(색상은 ARGB, 라벨은 표시 문자열 그대로).
class FmkStandingsWidgetRow {
  const FmkStandingsWidgetRow({
    required this.position,
    required this.name,
    required this.points,
    required this.changeLabel,
    required this.changeColor,
    required this.teamColor,
  });

  final int position;
  final String name;
  final String points;

  /// 순위 탭과 같은 표기: '▲2'/'▼1'/'—', 변동 정보 없으면 빈 문자열.
  final String changeLabel;
  final int changeColor;
  final int teamColor;
}

/// 드라이버 또는 컨스트럭터 순위 상위 5개를 위젯 행으로 변환한다.
/// (둘 중 하나만 넘길 것 — 드라이버가 우선.)
List<FmkStandingsWidgetRow> buildFmkStandingsWidgetRows({
  List<DriverStanding>? driverStandings,
  List<ConstructorStanding>? constructorStandings,
}) {
  FmkStandingsWidgetRow row({
    required int position,
    required String name,
    required String teamKo,
    required num points,
    required int? change,
  }) {
    // 순위 탭 _PositionChange 와 같은 규칙/색(green/redSoft/muted).
    final String label;
    final int color;
    if (change == null) {
      label = '';
      color = 0xFF7880A0;
    } else if (change > 0) {
      label = '▲$change';
      color = 0xFF4ADE80;
    } else if (change < 0) {
      label = '▼${change.abs()}';
      color = 0xFFF87171;
    } else {
      label = '—';
      color = 0xFF7880A0;
    }
    return FmkStandingsWidgetRow(
      position: position,
      name: name,
      points: _formatWidgetPoints(points),
      changeLabel: label,
      changeColor: color,
      teamColor: getTeamColor(teamKo).toARGB32(),
    );
  }

  if (driverStandings != null) {
    return [
      for (final d in driverStandings.take(5))
        row(
          position: d.position,
          name: d.driverKo,
          teamKo: d.teamKo,
          points: d.points,
          change: d.positionChange,
        ),
    ];
  }
  return [
    for (final c
        in (constructorStandings ?? const <ConstructorStanding>[]).take(5))
      row(
        position: c.position,
        name: c.teamKo,
        teamKo: c.teamKo,
        points: c.points,
        change: c.positionChange,
      ),
  ];
}

String _formatWidgetPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }
  return points.toString();
}

FmkHomeWidgetPayload buildFmkHomeWidgetPayload({
  LiveSessionSnapshot? snapshot,
  LatestRaceResult? latestResult,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final displayable =
      snapshot != null && isLiveSnapshotDisplayable(snapshot, currentTime);
  if (displayable) {
    return _buildLivePayload(snapshot, currentTime);
  }
  // 라이브가 없으면 최근 확정 결과를 우측 화면으로 제공(토글 상시 노출).
  if (latestResult != null && latestResult.data.entries.isNotEmpty) {
    return _buildResultPayload(latestResult, currentTime);
  }
  return _buildDefaultPayload(currentTime);
}

/// 확정 결과 모드: 우측 화면에 최근 그랑프리 Top 3(공식 결과)를 그린다.
/// 일정 화면 데이터는 항상 함께 저장한다(토글 전환용).
FmkHomeWidgetPayload _buildResultPayload(
  LatestRaceResult latest,
  DateTime now,
) {
  final race = getRaceById(latest.raceId);
  final schedule = _nextRaceSchedule(now);
  final topThree = latest.data.entries.take(3).toList();

  return FmkHomeWidgetPayload(
    mode: _modeResult,
    gpFlag: race != null ? _flagForRace(race) : '',
    gpName: race?.nameKo ?? '최근 레이스',
    scheduleGpFlag: _flagForRace(schedule.race),
    scheduleGpName: schedule.race.nameKo,
    scheduleRaceId: schedule.race.id,
    sessions: schedule.rows,
    sessionHighlightIndex: schedule.highlightIndex,
    liveBadge: 'RESULT',
    lapCurrent: 0,
    lapTotal: 0,
    // 확정 결과에는 드라이버 약어가 필요 없다(위젯이 이름만 그린다).
    topThree: List.filled(topThree.length, ''),
    topThreePositions: [for (final e in topThree) e.position],
    topThreeNames: [for (final e in topThree) e.driverKo],
    // 결과 패널과 같은 규칙: 1위는 총 시간, 이후는 갭(DNF 등은 '—').
    topThreeTimes: [
      for (final e in topThree)
        ((e.position == 1 ? e.time : e.gap) ?? '—').trim(),
    ],
    topThreeColors: [
      for (final e in topThree)
        _androidColorInt(getTeamColor(e.teamKo).toARGB32()),
    ],
  );
}

/// 다음 그랑프리와 세션 일정 행(최대 5개). 두 모드가 공유한다.
/// highlightIndex 는 아직 시작 전인 첫 세션(1-based, 없으면 0) — 진행 중
/// 세션은 위젯이 라이브 모드로 전환되므로 여기서 따로 다루지 않는다.
({Race race, List<FmkHomeWidgetSessionRow> rows, int highlightIndex})
_nextRaceSchedule(DateTime now) {
  final race = getNextRace(now);
  final sessions = race.sessions.take(5).toList();
  var highlightIndex = 0;
  final rows = <FmkHomeWidgetSessionRow>[];
  for (var i = 0; i < sessions.length; i++) {
    final start = getSessionDate(race, sessions[i]);
    final end = getSessionEndDate(race, sessions[i]);
    if (highlightIndex == 0 && start.isAfter(now)) highlightIndex = i + 1;
    rows.add(
      FmkHomeWidgetSessionRow(
        name: _sessionName(sessions[i]),
        date: _formatDateKst(start),
        time: _formatTimeKst(start),
        id: sessions[i].id,
        startEpochMs: start.toUtc().millisecondsSinceEpoch,
        endEpochMs: end.toUtc().millisecondsSinceEpoch,
      ),
    );
  }
  return (race: race, rows: rows, highlightIndex: highlightIndex);
}

FmkHomeWidgetPayload _buildDefaultPayload(DateTime now) {
  final schedule = _nextRaceSchedule(now);

  return FmkHomeWidgetPayload(
    mode: _modeDefault,
    gpFlag: _flagForRace(schedule.race),
    gpName: schedule.race.nameKo,
    scheduleGpFlag: _flagForRace(schedule.race),
    scheduleGpName: schedule.race.nameKo,
    scheduleRaceId: schedule.race.id,
    sessions: schedule.rows,
    sessionHighlightIndex: schedule.highlightIndex,
    liveBadge: 'LIVE',
    lapCurrent: 0,
    lapTotal: 0,
    topThree: const [],
    topThreePositions: const [],
    topThreeNames: const [],
    topThreeTimes: const [],
    topThreeColors: const [],
  );
}

FmkHomeWidgetPayload _buildLivePayload(
  LiveSessionSnapshot snapshot,
  DateTime now,
) {
  final race = resolveLiveRace(snapshot.raceId, snapshot.raceName);
  final topDrivers = snapshot.topThree
      .take(3)
      .where((driver) => driver.code.trim().isNotEmpty)
      .toList();
  final topThree = topDrivers
      .map((driver) => driver.code.trim().toUpperCase())
      .toList();
  final topThreePositions = topDrivers
      .map((driver) => driver.position)
      .toList();
  final topThreeNames = topDrivers.map(_driverDisplayNameKo).toList();
  final raceLike = snapshot.isRaceOrSprint;
  final topThreeTimes = topDrivers
      .map((driver) => _driverTime(driver, raceLike: raceLike))
      .toList();
  final topThreeColors = topDrivers
      .map(
        (driver) => _androidColorInt(liveDriverAccent(driver.code).toARGB32()),
      )
      .toList();
  final lapTotal = snapshot.totalLaps ?? 0;
  final lapCurrent = snapshot.currentLap ?? 0;
  // live 모드에서도 일정 데이터를 함께 저장해, 위젯 토글 버튼이 앱 실행 없이
  // 일정 화면을 그릴 수 있게 한다.
  final schedule = _nextRaceSchedule(now);

  return FmkHomeWidgetPayload(
    mode: _modeLive,
    gpFlag: _firstNonEmpty([
      snapshot.countryFlag,
      liveCountryFlag(snapshot.raceId),
      if (race != null) _flagForRace(race),
    ]),
    gpName: _firstNonEmpty([race?.nameKo, snapshot.raceName, '비아 포뮬러 라이브']),
    scheduleGpFlag: _flagForRace(schedule.race),
    scheduleGpName: schedule.race.nameKo,
    scheduleRaceId: schedule.race.id,
    sessions: schedule.rows,
    sessionHighlightIndex: schedule.highlightIndex,
    liveBadge: snapshot.isEnded && !isLiveSnapshotSessionActive(snapshot, now)
        ? 'RESULT'
        : 'LIVE',
    lapCurrent: lapCurrent < 0 ? 0 : lapCurrent,
    lapTotal: lapTotal < 0 ? 0 : lapTotal,
    topThree: topThree,
    topThreePositions: topThreePositions,
    topThreeNames: topThreeNames,
    topThreeTimes: topThreeTimes,
    topThreeColors: topThreeColors,
  );
}

int _androidColorInt(int argb) {
  final value = argb & 0xFFFFFFFF;
  return value >= 0x80000000 ? value - 0x100000000 : value;
}

String _sessionName(RaceSession session) {
  final fullLabel = session.fullLabel.trim();
  if (fullLabel.isNotEmpty) return fullLabel;
  return session.label.trim().isEmpty ? '세션' : session.label.trim();
}

String _flagForRace(Race race) => getCountryFlag(race.countryKo);

String _formatDateKst(DateTime value) {
  final kst = _toKst(value);
  return '${kst.month}.${kst.day} ${_weekdayKo(kst.weekday)}';
}

String _formatTimeKst(DateTime value) {
  final kst = _toKst(value);
  return '${_two(kst.hour)}:${_two(kst.minute)}';
}

DateTime _toKst(DateTime value) => value.toUtc().add(const Duration(hours: 9));

String _two(int value) => value.toString().padLeft(2, '0');

String _weekdayKo(int weekday) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[weekday - 1];
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _driverDisplayNameKo(LiveDriverPosition driver) {
  return driverNameKo(driver.code, driver.displayName.trim());
}

String _driverTime(LiveDriverPosition driver, {required bool raceLike}) {
  final value = driver.time(raceLike: raceLike).trim();
  return value.isEmpty ? '—' : value;
}
