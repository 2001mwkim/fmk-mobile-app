import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/country_flags.dart';
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

FmkHomeWidgetPayload _buildDefaultPayload(DateTime now) {
  final race = getNextRace(now);
  final sessions = race.sessions.take(5).map((session) {
    final start = getSessionDate(race, session);
    return FmkHomeWidgetSessionRow(
      name: _sessionName(session),
      date: _formatDateKst(start),
      time: _formatTimeKst(start),
    );
  }).toList();

  return FmkHomeWidgetPayload(
    mode: _modeDefault,
    gpFlag: _flagForRace(race),
    gpName: race.nameKo,
    sessions: sessions,
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

  return FmkHomeWidgetPayload(
    mode: _modeLive,
    gpFlag: _firstNonEmpty([
      snapshot.countryFlag,
      liveCountryFlag(snapshot.raceId),
      if (race != null) _flagForRace(race),
    ]),
    gpName: _firstNonEmpty([race?.nameKo, snapshot.raceName, '포매코 라이브']),
    sessions: const [],
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
  final code = driver.code.trim().toUpperCase();
  return _driverNameKoByCode[code] ?? driver.displayName.trim();
}

String _driverTime(LiveDriverPosition driver, {required bool raceLike}) {
  final value = driver.gap(raceLike: raceLike).trim();
  return value.isEmpty ? '—' : value;
}

const Map<String, String> _driverNameKoByCode = {
  'NOR': '랜도 노리스',
  'PIA': '오스카 피아스트리',
  'VER': '막스 베르스타펜',
  'TSU': '유키 츠노다',
  'LEC': '샤를 르클레르',
  'HAM': '루이스 해밀턴',
  'RUS': '조지 러셀',
  'ANT': '키미 안토넬리',
  'SAI': '카를로스 사인츠',
  'ALB': '알렉산더 알본',
  'ALO': '페르난도 알론소',
  'STR': '랜스 스트롤',
  'GAS': '피에르 가슬리',
  'COL': '프랑코 콜라핀토',
  'OCO': '에스테반 오콘',
  'BEA': '올리버 베어먼',
  'HAD': '아이작 하자르',
  'LAW': '리암 로슨',
  'HUL': '니코 휠켄베르크',
  'BOR': '가브리엘 보르톨레토',
  'BOT': '발테리 보타스',
  'PER': '세르히오 페레즈',
  'LIN': '아비드 린드블라드',
};
