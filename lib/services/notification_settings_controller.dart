import 'package:shared_preferences/shared_preferences.dart';

import '../data/races.dart' as race_data;
import '../models/race.dart';
import 'notification_service.dart';

// 신형: 카테고리별 on/off 키(notification_cat_<name>).
String _categoryKey(SessionCategory category) =>
    'notification_cat_${category.name}';

// 레거시: 전체/레이스만 2개 불리언(구버전에서 저장된 값 마이그레이션용).
const String _legacyAllSessionsKey = 'notification_all_sessions_30m';
const String _legacyRaceOnlyKey = 'notification_race_only_30m';

abstract class NotificationSettingsStore {
  Future<NotificationPreferences> load();
  Future<void> save(NotificationPreferences preferences);
}

class SharedPreferencesNotificationSettingsStore
    implements NotificationSettingsStore {
  const SharedPreferencesNotificationSettingsStore();

  @override
  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();

    // 신형 키가 하나라도 있으면 신형으로 로드.
    final hasNew = SessionCategory.values.any(
      (category) => prefs.containsKey(_categoryKey(category)),
    );
    if (hasNew) {
      final categories = <SessionCategory>{
        for (final category in SessionCategory.values)
          if (prefs.getBool(_categoryKey(category)) ?? false) category,
      };
      return NotificationPreferences(categories: categories);
    }

    // 레거시(전체/레이스만) → 카테고리로 1회 마이그레이션.
    final legacyAll = prefs.getBool(_legacyAllSessionsKey) ?? false;
    final legacyRaceOnly = prefs.getBool(_legacyRaceOnlyKey) ?? false;
    if (legacyAll) {
      return NotificationPreferences(
        categories: SessionCategory.values.toSet(),
      );
    }
    if (legacyRaceOnly) {
      return const NotificationPreferences(
        categories: {SessionCategory.race},
      );
    }
    return const NotificationPreferences();
  }

  @override
  Future<void> save(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    for (final category in SessionCategory.values) {
      await prefs.setBool(
        _categoryKey(category),
        preferences.contains(category),
      );
    }
    // 혼선 방지를 위해 레거시 키는 제거한다.
    await prefs.remove(_legacyAllSessionsKey);
    await prefs.remove(_legacyRaceOnlyKey);
  }
}

class NotificationSettingsUpdateResult {
  const NotificationSettingsUpdateResult({
    required this.preferences,
    required this.scheduledCount,
    this.permissionDenied = false,
  });

  final NotificationPreferences preferences;
  final int scheduledCount;
  final bool permissionDenied;
}

class NotificationSettingsController {
  NotificationSettingsController({
    NotificationSettingsStore? store,
    SessionNotificationScheduler? scheduler,
    SessionNotificationPlanner? planner,
    Iterable<Race>? races,
    DateTime Function()? now,
  }) : _store = store ?? const SharedPreferencesNotificationSettingsStore(),
       _scheduler = scheduler ?? FlutterSessionNotificationScheduler(),
       _planner = planner ?? SessionNotificationPlanner(),
       _races = races ?? race_data.races,
       _now = now ?? DateTime.now;

  final NotificationSettingsStore _store;
  final SessionNotificationScheduler _scheduler;
  final SessionNotificationPlanner _planner;
  final Iterable<Race> _races;
  final DateTime Function() _now;

  Future<NotificationPreferences> load() => _store.load();

  Future<NotificationSettingsUpdateResult> update({
    required SessionCategory category,
    required bool enabled,
  }) async {
    final current = await _store.load();
    final next = current.withCategory(category, enabled);

    // 켤 때만 권한을 확인한다(끄기만 할 땐 불필요). 거부되면 전부 끈다.
    if (enabled) {
      final granted = await _scheduler.requestPermission();
      if (!granted) {
        const disabled = NotificationPreferences();
        await _store.save(disabled);
        await _cancelAll();
        return const NotificationSettingsUpdateResult(
          preferences: disabled,
          scheduledCount: 0,
          permissionDenied: true,
        );
      }
    }

    await _store.save(next);
    final scheduledCount = await _reschedule(next);
    return NotificationSettingsUpdateResult(
      preferences: next,
      scheduledCount: scheduledCount,
    );
  }

  Future<int> refreshScheduledNotifications() async {
    final preferences = await _store.load();
    return _reschedule(preferences);
  }

  Future<int> _reschedule(NotificationPreferences preferences) async {
    await _cancelAll();
    if (!preferences.hasAnyEnabled) return 0;

    final notifications = _planner.buildSchedule(
      races: _races,
      preferences: preferences,
      now: _now(),
    );
    await _scheduler.schedule(notifications);
    return notifications.length;
  }

  Future<void> _cancelAll() {
    return _scheduler.cancelNotifications(_planner.allNotificationIds(_races));
  }
}

final notificationSettingsController = NotificationSettingsController();
