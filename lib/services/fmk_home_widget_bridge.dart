import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/country_flags.dart';
import '../data/drivers.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import 'live_session_controller.dart';

const String fmkHomeWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkHomeWidgetProvider';

const String _modeDefault = 'default';
const String _modeLive = 'live';

class FmkHomeWidgetPayload {
  const FmkHomeWidgetPayload({
    required this.mode,
    required this.gpFlag,
    required this.gpName,
    required this.scheduleGpFlag,
    required this.scheduleGpName,
    required this.sessions,
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
  final String liveBadge;
  final int lapCurrent;
  final int lapTotal;
  final List<String> topThree;
  final List<int> topThreePositions;
  final List<String> topThreeNames;
  final List<String> topThreeTimes;
  final List<int> topThreeColors;

  bool get isLive => mode == _modeLive;
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

  static void bindTo(LiveSessionController controller) {
    if (_bound) return;
    _bound = true;
    controller.addListener(() {
      unawaited(update(snapshot: controller.snapshot));
    });
  }

  static Future<void> update({
    LiveSessionSnapshot? snapshot,
    DateTime? now,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final payload = buildFmkHomeWidgetPayload(snapshot: snapshot, now: now);

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
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final displayable =
      snapshot != null && isLiveSnapshotDisplayable(snapshot, currentTime);
  if (displayable) {
    return _buildLivePayload(snapshot, currentTime);
  }
  return _buildDefaultPayload(currentTime);
}

/// 다음 그랑프리와 세션 일정 행(최대 5개). 두 모드가 공유한다.
({Race race, List<FmkHomeWidgetSessionRow> rows}) _nextRaceSchedule(
  DateTime now,
) {
  final race = getNextRace(now);
  final rows = race.sessions.take(5).map((session) {
    final start = getSessionDate(race, session);
    return FmkHomeWidgetSessionRow(
      name: _sessionName(session),
      date: _formatDateKst(start),
      time: _formatTimeKst(start),
    );
  }).toList();
  return (race: race, rows: rows);
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
