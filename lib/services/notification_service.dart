import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/races.dart' show getSessionEndDate;
import '../models/race.dart';
import '../models/race_session.dart';

const String kstTimeZoneName = 'Asia/Seoul';
const int notificationGrandPrixWindow = 3;
const String androidNotificationIcon = 'ic_notification';

/// 알림을 켤 수 있는 세션 묶음. 연습(FP1~3) / 퀄리파잉 / 스프린트(스프린트
/// 퀄리파잉·스프린트) / 레이스로 나눈다. 사용자가 종류별로 따로 켤 수 있다.
enum SessionCategory { practice, qualifying, sprint, race }

/// 세션 id → 카테고리. 매핑 없는 id 는 null(알림 대상 아님).
/// 세션 id 는 races.dart 데이터에서 온다(fp1/fp2/fp3/qualifying/
/// sprint_qualifying/sprint/race).
SessionCategory? sessionCategoryOf(String sessionId) {
  switch (sessionId) {
    case 'fp1':
    case 'fp2':
    case 'fp3':
      return SessionCategory.practice;
    case 'qualifying':
      return SessionCategory.qualifying;
    case 'sprint':
    case 'sprint_qualifying':
      return SessionCategory.sprint;
    case 'race':
      return SessionCategory.race;
    default:
      return null;
  }
}

/// 세션 시작 몇 분 전에 알릴지 고를 수 있는 값. 기본 30분(종전 고정값).
const List<int> notificationLeadMinuteOptions = <int>[5, 15, 30, 60];
const int defaultNotificationLeadMinutes = 30;

/// 결과 알림은 세션 예상 종료 후 이만큼 뒤에 보낸다(공식 결과 집계 여유).
const Duration resultReminderDelay = Duration(minutes: 5);

class NotificationPreferences {
  const NotificationPreferences({
    this.categories = const <SessionCategory>{},
    this.leadMinutes = defaultNotificationLeadMinutes,
    this.resultReminders = false,
    this.mutedRaceIds = const <String>{},
  });

  /// 알림을 켠 세션 카테고리 집합.
  final Set<SessionCategory> categories;

  /// 시작 알림 시점(분 전). [notificationLeadMinuteOptions] 중 하나.
  final int leadMinutes;

  /// 켠 카테고리 세션이 끝나면 "결과가 나왔어요" 알림을 보낼지. 로컬 알림이라
  /// 결과 내용은 모른다 — 그래서 본문에 순위를 넣지 않아 스포일러도 없다.
  final bool resultReminders;

  /// 알림을 끈 그랑프리(raceId). 새벽 GP 하나만 끄고 싶을 때.
  final Set<String> mutedRaceIds;

  Duration get leadTime => Duration(minutes: leadMinutes);

  bool get hasAnyEnabled => categories.isNotEmpty;

  bool contains(SessionCategory category) => categories.contains(category);

  bool isRaceMuted(String raceId) => mutedRaceIds.contains(raceId);

  NotificationPreferences copyWith({
    Set<SessionCategory>? categories,
    int? leadMinutes,
    bool? resultReminders,
    Set<String>? mutedRaceIds,
  }) {
    return NotificationPreferences(
      categories: categories ?? this.categories,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      resultReminders: resultReminders ?? this.resultReminders,
      mutedRaceIds: mutedRaceIds ?? this.mutedRaceIds,
    );
  }

  /// [category] 를 켜거나(추가) 끈(제거) 새 설정을 만든다.
  NotificationPreferences withCategory(SessionCategory category, bool enabled) {
    final next = Set<SessionCategory>.of(categories);
    if (enabled) {
      next.add(category);
    } else {
      next.remove(category);
    }
    return copyWith(categories: next);
  }

  /// [raceId] 알림을 끄거나(muted=true) 다시 켠 새 설정.
  NotificationPreferences withRaceMuted(String raceId, bool muted) {
    final next = Set<String>.of(mutedRaceIds);
    if (muted) {
      next.add(raceId);
    } else {
      next.remove(raceId);
    }
    return copyWith(mutedRaceIds: next);
  }
}

/// 세션 알림 종류: 시작 전 알림 / 종료 후 결과 알림.
enum SessionNotificationKind { reminder, result }

class ScheduledSessionNotification {
  const ScheduledSessionNotification({
    required this.id,
    required this.raceId,
    required this.sessionId,
    required this.category,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.kind = SessionNotificationKind.reminder,
  });

  final int id;
  final String raceId;
  final String sessionId;
  final SessionCategory category;
  final SessionNotificationKind kind;
  final String title;
  final String body;
  final tz.TZDateTime scheduledAt;
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
      if (race.isCancelled || preferences.isRaceMuted(race.id)) continue;

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
        ids.add(resultNotificationIdFor(race, index));
      }
    }
    return ids;
  }

  int notificationIdFor(Race race, int sessionIndex) {
    return 260000 + race.round * 10 + sessionIndex;
  }

  /// 결과 알림 id. 시작 알림(26xxxx)과 겹치지 않게 27xxxx 대역을 쓴다.
  int resultNotificationIdFor(Race race, int sessionIndex) {
    return 270000 + race.round * 10 + sessionIndex;
  }

  List<ScheduledSessionNotification> _buildRaceNotifications({
    required Race race,
    required NotificationPreferences preferences,
    required tz.TZDateTime nowKst,
  }) {
    final notifications = <ScheduledSessionNotification>[];

    for (var index = 0; index < race.sessions.length; index++) {
      final session = race.sessions[index];
      final category = sessionCategoryOf(session.id);
      if (category == null || !preferences.contains(category)) continue;

      final sessionStart = _sessionStartAt(race, session);
      if (sessionStart == null) continue;

      final reminderAt = sessionStart.subtract(preferences.leadTime);
      if (reminderAt.isAfter(nowKst)) {
        notifications.add(
          ScheduledSessionNotification(
            id: notificationIdFor(race, index),
            raceId: race.id,
            sessionId: session.id,
            category: category,
            title: category == SessionCategory.race
                ? '비아 포뮬러 레이스 알림'
                : '비아 포뮬러 세션 알림',
            // 비정확 알람으로 폴백되거나 기기 정책으로 표시가 늦어져도
            // "30분 뒤"처럼 잘못된 정보를 주지 않도록 절대 시각을 표시한다.
            body:
                '${race.nameKo} ${session.label} 시작: '
                '${_formatSessionStart(sessionStart)}',
            scheduledAt: reminderAt,
          ),
        );
      }

      if (preferences.resultReminders) {
        final resultAt = tz.TZDateTime.from(
          getSessionEndDate(race, session),
          _location,
        ).add(resultReminderDelay);
        if (resultAt.isAfter(nowKst)) {
          notifications.add(
            ScheduledSessionNotification(
              id: resultNotificationIdFor(race, index),
              raceId: race.id,
              sessionId: session.id,
              category: category,
              kind: SessionNotificationKind.result,
              title: '비아 포뮬러 결과 알림',
              // 결과 내용을 모르는 로컬 알림이고, 녹화 시청자를 위해 순위는
              // 일부러 넣지 않는다.
              body: '${race.nameKo} ${session.label} 결과가 나왔어요.',
              scheduledAt: resultAt,
            ),
          );
        }
      }
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

class NotificationPermissionDenied implements Exception {
  const NotificationPermissionDenied();
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
  // 초기화가 실패(예: 아이콘 리소스 누락)하면 알림 기능을 조용히 비활성화한다.
  bool _unavailable = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
        'fmk_session_reminders',
        '세션 알림',
        channelDescription: '그랑프리 세션 시작 전·결과 알림',
        icon: androidNotificationIcon,
        importance: Importance.high,
        priority: Priority.high,
      );

  static const DarwinNotificationDetails _darwinDetails =
      DarwinNotificationDetails();

  @override
  Future<void> initialize() async {
    if (_initialized || _unavailable) return;

    try {
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
    } catch (error) {
      // 아이콘 리소스 누락 등으로 초기화가 실패해도 앱을 죽이지 않는다.
      // (plugin.initialize 의 PlatformException 이 unawaited 경로에서 fatal 로
      // 보고되던 문제 방어 — 알림만 조용히 비활성화.)
      _unavailable = true;
      debugPrint('알림 초기화 실패 — 알림 비활성화: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (_unavailable) return false;

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
    if (_unavailable) return;
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> schedule(
    List<ScheduledSessionNotification> notifications,
  ) async {
    await initialize();
    if (_unavailable) return;
    if (notifications.isEmpty) return;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      if (permissions == null ||
          (!permissions.isEnabled && !permissions.isProvisionalEnabled)) {
        throw const NotificationPermissionDenied();
      }
    }
    const details = NotificationDetails(
      android: _androidDetails,
      iOS: _darwinDetails,
    );
    final androidScheduleMode = await _androidScheduleMode();

    for (final notification in notifications) {
      try {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          scheduledDate: notification.scheduledAt,
          notificationDetails: details,
          androidScheduleMode: androidScheduleMode,
          payload: '${notification.raceId}:${notification.sessionId}',
        );
      } on PlatformException catch (error) {
        // Authorization can change after checkPermissions completes.
        if (isIOS &&
            error.code == 'Error 2003' &&
            error.details == 'UNErrorDomain') {
          throw const NotificationPermissionDenied();
        }
        rethrow;
      }
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
