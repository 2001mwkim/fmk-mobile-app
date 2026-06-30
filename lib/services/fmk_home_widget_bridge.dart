import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import 'live_session_controller.dart';

const String fmkHomeWidgetProviderQualifiedName =
    'kr.formulamagazine.fmk.FmkHomeWidgetProvider';

const String _badgeKey = 'fmk_widget_badge';
const String _titleKey = 'fmk_widget_title';
const String _primaryKey = 'fmk_widget_primary';
const String _secondaryKey = 'fmk_widget_secondary';
const String _updatedKey = 'fmk_widget_updated';

class FmkHomeWidgetPayload {
  const FmkHomeWidgetPayload({
    required this.badge,
    required this.title,
    required this.primary,
    required this.secondary,
    required this.updated,
  });

  final String badge;
  final String title;
  final String primary;
  final String secondary;
  final String updated;
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
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_badgeKey, payload.badge),
        HomeWidget.saveWidgetData<String>(_titleKey, payload.title),
        HomeWidget.saveWidgetData<String>(_primaryKey, payload.primary),
        HomeWidget.saveWidgetData<String>(_secondaryKey, payload.secondary),
        HomeWidget.saveWidgetData<String>(_updatedKey, payload.updated),
      ]);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: fmkHomeWidgetProviderQualifiedName,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update Fmk home widget: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

FmkHomeWidgetPayload buildFmkHomeWidgetPayload({
  LiveSessionSnapshot? snapshot,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final displayableSnapshot = snapshot != null && snapshot.isDisplayable
      ? snapshot
      : null;

  if (displayableSnapshot != null) {
    return _buildLivePayload(displayableSnapshot, currentTime);
  }

  return _buildNextSessionPayload(currentTime);
}

FmkHomeWidgetPayload _buildLivePayload(
  LiveSessionSnapshot snapshot,
  DateTime now,
) {
  final race = getRaceById(snapshot.raceId);
  final title = _firstNonEmpty([snapshot.raceName, race?.nameKo, '포매코 라이브']);
  final topThree = _topThreeCodes(snapshot);
  final updated = _liveUpdatedLabel(snapshot, now);

  if (snapshot.isEnded) {
    return FmkHomeWidgetPayload(
      badge: '최종 결과',
      title: title,
      primary: topThree,
      secondary: snapshot.sessionTitle,
      updated: updated,
    );
  }

  return FmkHomeWidgetPayload(
    badge: 'LIVE',
    title: title,
    primary: _lapLabel(snapshot),
    secondary: topThree,
    updated: updated,
  );
}

FmkHomeWidgetPayload _buildNextSessionPayload(DateTime now) {
  final race = getNextRace(now);
  final session = getNextSession(race, now);
  final sessionStart = session == null ? null : getSessionDate(race, session);
  final isStartingSoon =
      sessionStart != null &&
      sessionStart.isAfter(now) &&
      sessionStart.difference(now) <= const Duration(minutes: 30);

  return FmkHomeWidgetPayload(
    badge: isStartingSoon ? '곧 시작' : '다음 세션',
    title: race.nameKo,
    primary: session?.fullLabel ?? '세션 일정 준비 중',
    secondary: _nextSessionSecondary(race, session, sessionStart),
    updated: _updatedLabel(now),
  );
}

String _nextSessionSecondary(
  Race race,
  RaceSession? session,
  DateTime? sessionStart,
) {
  final location = _firstNonEmpty([race.circuitKo, race.countryKo]);
  if (session == null || sessionStart == null) return location;
  return '한국시간 ${_formatDateTimeKst(sessionStart)} · $location';
}

String _lapLabel(LiveSessionSnapshot snapshot) {
  if (snapshot.currentLap != null && snapshot.totalLaps != null) {
    return 'Lap ${snapshot.currentLap} / ${snapshot.totalLaps}';
  }
  return snapshot.sessionTitle;
}

String _topThreeCodes(LiveSessionSnapshot snapshot) {
  final codes = snapshot.topThree
      .take(3)
      .map((driver) => driver.code.trim())
      .where((code) => code.isNotEmpty)
      .toList();
  if (codes.isEmpty) return 'Top 3 집계 중';
  return 'Top 3 ${codes.join(' · ')}';
}

String _liveUpdatedLabel(LiveSessionSnapshot snapshot, DateTime fallback) {
  final parsed = DateTime.tryParse(snapshot.updatedAt);
  return _updatedLabel(parsed ?? fallback);
}

String _updatedLabel(DateTime value) {
  final kst = _toKst(value);
  return '업데이트 ${_two(kst.hour)}:${_two(kst.minute)} KST';
}

String _formatDateTimeKst(DateTime value) {
  final kst = _toKst(value);
  return '${kst.month}.${kst.day} ${_two(kst.hour)}:${_two(kst.minute)} KST';
}

DateTime _toKst(DateTime value) => value.toUtc().add(const Duration(hours: 9));

String _two(int value) => value.toString().padLeft(2, '0');

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return '';
}
