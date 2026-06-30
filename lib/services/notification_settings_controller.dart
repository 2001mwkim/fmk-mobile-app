import 'package:shared_preferences/shared_preferences.dart';

import '../data/races.dart' as race_data;
import '../models/race.dart';
import 'notification_service.dart';

const String _allSessionsKey = 'notification_all_sessions_30m';
const String _raceOnlyKey = 'notification_race_only_30m';

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
    return NotificationPreferences(
      allSessions30m: prefs.getBool(_allSessionsKey) ?? false,
      raceOnly30m: prefs.getBool(_raceOnlyKey) ?? false,
    );
  }

  @override
  Future<void> save(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_allSessionsKey, preferences.allSessions30m);
    await prefs.setBool(_raceOnlyKey, preferences.raceOnly30m);
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
    bool? allSessions30m,
    bool? raceOnly30m,
  }) async {
    final current = await _store.load();
    final next = current.copyWith(
      allSessions30m: allSessions30m,
      raceOnly30m: raceOnly30m,
    );

    if (next.hasAnyEnabled) {
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
