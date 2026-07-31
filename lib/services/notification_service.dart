import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/race.dart';
import '../models/race_session.dart';

const Duration sessionNotificationLeadTime = Duration(minutes: 30);
const String kstTimeZoneName = 'Asia/Seoul';
const int notificationGrandPrixWindow = 3;
const String androidNotificationIcon = 'ic_notification';

class NotificationPreferences {
  const NotificationPreferences({
    this.allSessions30m = false,
    this.raceOnly30m = false,
  });

  final bool allSessions30m;
  final bool raceOnly30m;

  bool get hasAnyEnabled => allSessions30m || raceOnly30m;

  NotificationPreferences copyWith({bool? allSessions30m, bool? raceOnly30m}) {
    return NotificationPreferences(
      allSessions30m: allSessions30m ?? this.allSessions30m,
      raceOnly30m: raceOnly30m ?? this.raceOnly30m,
    );
  }
}

enum ScheduledNotificationKind { allSession, raceOnly }

class ScheduledSessionNotification {
  const ScheduledSessionNotification({
    required this.id,
    required this.raceId,
    required this.sessionId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.kind,
  });

  final int id;
  final String raceId;
  final String sessionId;
  final String title;
  final String body;
  final tz.TZDateTime scheduledAt;
  final ScheduledNotificationKind kind;
}

class SessionNotificationPlanner {
  SessionNotificationPlanner({tz.Location? location})
    : _location = location ?? NotificationTimeZones.kst();

  final tz.Location _location;

  List<ScheduledSessionNotification> buildSchedule({
    required Iterable<Race> races,
    required NotificationPreferences preferences,
    required DateTime now,
  }) {
    if (!preferences.hasAnyEnabled) return const [];

    final nowKst = tz.TZDateTime.from(now, _location);
    final candidates = <_RaceNotificationCandidate>[];

    for (final race in races) {
      if (race.isCancelled) continue;

      final notifications = _buildRaceNotifications(
        race: race,
        preferences: preferences,
        nowKst: nowKst,
      );
      if (notifications.isEmpty) continue;

      candidates.add(
        _RaceNotificationCandidate(
          firstScheduledAt: notifications
              .map((notification) => notification.scheduledAt)
              .reduce((a, b) => a.isBefore(b) ? a : b),
          notifications: notifications,
        ),
      );
    }

    candidates.sort((a, b) => a.firstScheduledAt.compareTo(b.firstScheduledAt));

    return candidates
        .take(notificationGrandPrixWindow)
        .expand((candidate) => candidate.notifications)
        .toList();
  }

  Set<int> allNotificationIds(Iterable<Race> races) {
    final ids = <int>{};
    for (final race in races) {
      for (var index = 0; index < race.sessions.length; index++) {
        ids.add(notificationIdFor(race, index));
      }
    }
    return ids;
  }

  int notificationIdFor(Race race, int sessionIndex) {
    return 260000 + race.round * 10 + sessionIndex;
  }

  List<ScheduledSessionNotification> _buildRaceNotifications({
    required Race race,
    required NotificationPreferences preferences,
    required tz.TZDateTime nowKst,
  }) {
    final notifications = <ScheduledSessionNotification>[];

    for (var index = 0; index < race.sessions.length; index++) {
      final session = race.sessions[index];
      final shouldSchedule = preferences.allSessions30m
          ? true
          : preferences.raceOnly30m && session.id == 'race';
      if (!shouldSchedule) continue;

      final sessionStart = _sessionStartAt(race, session);
      if (sessionStart == null) continue;

      final reminderAt = sessionStart.subtract(sessionNotificationLeadTime);
      if (!reminderAt.isAfter(nowKst)) continue;

      final kind = preferences.allSessions30m
          ? ScheduledNotificationKind.allSession
          : ScheduledNotificationKind.raceOnly;

      notifications.add(
        ScheduledSessionNotification(
          id: notificationIdFor(race, index),
          raceId: race.id,
          sessionId: session.id,
          title: kind == ScheduledNotificationKind.raceOnly
              ? '비아 포뮬러 레이스 알림'
              : '비아 포뮬러 세션 알림',
          // 비정확 알람으로 폴백되거나 기기 정책으로 표시가 늦어져도
          // "30분 뒤"처럼 잘못된 정보를 주지 않도록 절대 시각을 표시한다.
          body:
              '${race.nameKo} ${session.label} 시작: '
              '${_formatSessionStart(sessionStart)}',
          scheduledAt: reminderAt,
          kind: kind,
        ),
      );
    }

    return notifications;
  }

  String _formatSessionStart(tz.TZDateTime sessionStart) {
    final hour = sessionStart.hour.toString().padLeft(2, '0');
    final minute = sessionStart.minute.toString().padLeft(2, '0');
    return '${sessionStart.month}월 ${sessionStart.day}일 '
        '$hour:$minute (KST)';
  }

  tz.TZDateTime? _sessionStartAt(Race race, RaceSession session) {
    final year = int.tryParse(race.startDate.split('-').first);
    final dateMatch = RegExp(r'^(\d{1,2})\.(\d{1,2})').firstMatch(session.date);
    final timeParts = session.time.split(':');
    if (year == null || dateMatch == null || timeParts.length != 2) {
      return null;
    }

    final month = int.tryParse(dateMatch.group(1)!);
    final day = int.tryParse(dateMatch.group(2)!);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (month == null || day == null || hour == null || minute == null) {
      return null;
    }

    return tz.TZDateTime(_location, year, month, day, hour, minute);
  }
}

class _RaceNotificationCandidate {
  const _RaceNotificationCandidate({
    required this.firstScheduledAt,
    required this.notifications,
  });

  final tz.TZDateTime firstScheduledAt;
  final List<ScheduledSessionNotification> notifications;
}

abstract class SessionNotificationScheduler {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> cancelNotifications(Iterable<int> ids);
  Future<void> schedule(List<ScheduledSessionNotification> notifications);
}

class FlutterSessionNotificationScheduler
    implements SessionNotificationScheduler {
  FlutterSessionNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'fmk_session_reminders',
        '세션 알림',
        channelDescription: '그랑프리 세션 시작 30분 전 알림',
        icon: androidNotificationIcon,
        importance: Importance.high,
        priority: Priority.high,
      );

  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails();

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    NotificationTimeZones.kst();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(androidNotificationIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();

    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationGranted = await androidPlugin
          ?.requestNotificationsPermission();
      if (notificationGranted == false) return false;

      // Android 12+의 "알람 및 리마인더" 특수 권한이다. 사용자가 거부해도
      // 알림 기능 자체는 유지하고 schedule()에서 비정확 알람으로 폴백한다.
      await androidPlugin?.requestExactAlarmsPermission();
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    return true;
  }

  @override
  Future<void> cancelNotifications(Iterable<int> ids) async {
    await initialize();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> schedule(
    List<ScheduledSessionNotification> notifications,
  ) async {
    await initialize();
    const details = NotificationDetails(
      android: _androidDetails,
      iOS: _darwinDetails,
    );
    final androidScheduleMode = await _androidScheduleMode();

    for (final notification in notifications) {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: notification.scheduledAt,
        notificationDetails: details,
        androidScheduleMode: androidScheduleMode,
        payload: '${notification.raceId}:${notification.sessionId}',
      );
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }

    final canScheduleExact = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return canScheduleExact == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

class NotificationTimeZones {
  const NotificationTimeZones._();

  static bool _initialized = false;

  static tz.Location kst() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    return tz.getLocation(kstTimeZoneName);
  }
}
