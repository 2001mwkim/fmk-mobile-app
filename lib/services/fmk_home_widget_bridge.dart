import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/country_flags.dart';
import '../data/drivers.dart';
import '../data/races.dart';
import '../data/team_colors.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import 'live_session_controller.dart';
import 'live_session_service.dart';
import 'race_results_repository.dart';

const String fmkHomeWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkHomeWidgetProvider';

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
  });

  final String name;
  final String date;
  final String time;
}

class FmkHomeWidgetBridge {
  const FmkHomeWidgetBridge._();

  static bool _bound = false;

  /// 최근 확정 결과 캐시 — 라이브가 없을 때 위젯 '결과' 화면의 데이터.
  /// 확정 결과는 레이스 후 바뀌지 않으므로 낡아도 틀리지 않는다.
  static LatestRaceResult? _latestResult;
  static DateTime? _latestResultFetchedAt;

  /// 테스트 주입 지점(기본은 실서버 /api/race-results).
  @visibleForTesting
  static RaceResultsRepository resultsRepository =
      const HttpRaceResultsRepository();

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

  static Future<void> update({
    LiveSessionSnapshot? snapshot,
    DateTime? now,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    await _ensureLatestResult();
    final payload = buildFmkHomeWidgetPayload(
      snapshot: snapshot,
      latestResult: _latestResult,
      now: now,
    );

    try {
      await _savePayload(payload);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkHomeWidgetProviderQualifiedName,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update Fmk home widget: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 런처에 위젯 고정(pin) 다이얼로그를 요청한다. 다이얼로그를 띄웠으면 true,
  /// 미지원 런처/플랫폼이면 false — 호출부가 수동 추가 안내를 띄운다.
  static Future<bool> requestPinWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: fmkHomeWidgetProviderQualifiedName,
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
FmkHomeWidgetPayload _buildResultPayload(LatestRaceResult latest, DateTime now) {
  final race = getRaceById(latest.raceId);
  final schedule = _nextRaceSchedule(now);
  final topThree = latest.data.entries.take(3).toList();

  return FmkHomeWidgetPayload(
    mode: _modeResult,
    gpFlag: race != null ? _flagForRace(race) : '',
    gpName: race?.nameKo ?? '최근 레이스',
    scheduleGpFlag: _flagForRace(schedule.race),
    scheduleGpName: schedule.race.nameKo,
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
    if (highlightIndex == 0 && start.isAfter(now)) highlightIndex = i + 1;
    rows.add(
      FmkHomeWidgetSessionRow(
        name: _sessionName(sessions[i]),
        date: _formatDateKst(start),
        time: _formatTimeKst(start),
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
