import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/race.dart';
import 'package:fmk_app/models/race_session.dart';
import 'package:fmk_app/services/notification_service.dart';
import 'package:fmk_app/services/notification_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iOS notification authorization', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <String>[];
    var authorized = false;
    var provisional = false;
    PlatformException? scheduleError;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      calls.clear();
      authorized = false;
      provisional = false;
      scheduleError = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'checkPermissions') {
              return {
                'isEnabled': authorized,
                'isProvisionalEnabled': provisional,
              };
            }
            if (call.method == 'zonedSchedule' && scheduleError != null) {
              throw scheduleError!;
            }
            return true;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    NotificationSettingsController controller() =>
        NotificationSettingsController(
          store: _MemoryNotificationSettingsStore()
            ..preferences = const NotificationPreferences(
              categories: {SessionCategory.practice, SessionCategory.race},
            ),
          scheduler: FlutterSessionNotificationScheduler(),
          races: [_futureRace(year: DateTime.now().year + 1)],
          now: () => DateTime.utc(DateTime.now().year + 1, 6, 30),
        );

    test(
      'startup skips denied permissions and retries after authorization',
      () async {
        final subject = controller();
        expect(await subject.refreshScheduledNotifications(), 0);
        expect(calls, isNot(contains('zonedSchedule')));
        expect(calls, isNot(contains('requestPermissions')));
        expect((await subject.load()).hasAnyEnabled, isTrue);
        authorized = true;
        expect(await subject.refreshScheduledNotifications(), 4);
        expect(
          calls.where((method) => method == 'zonedSchedule'),
          hasLength(4),
        );
      },
    );

    test('provisional authorization permits scheduling', () async {
      provisional = true;
      expect(await controller().refreshScheduledNotifications(), 4);
    });

    test('revocation during scheduling does not escape startup', () async {
      authorized = true;
      scheduleError = PlatformException(
        code: 'Error 2003',
        details: 'UNErrorDomain',
      );
      expect(await controller().refreshScheduledNotifications(), 0);
      expect(calls.where((method) => method == 'zonedSchedule'), hasLength(1));
    });

    test('settings update reports revoked permission', () async {
      final result = await controller().update(
        category: SessionCategory.practice,
        enabled: false,
      );
      expect(result.permissionDenied, isTrue);
      expect(result.scheduledCount, 0);
    });

    test('unrelated platform failures remain visible', () async {
      authorized = true;
      scheduleError = PlatformException(
        code: 'Error 2003',
        details: 'OtherDomain',
      );
      await expectLater(
        controller().refreshScheduledNotifications(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('Notification settings store', () {
    test('defaults to all categories off', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesNotificationSettingsStore();

      final preferences = await store.load();

      expect(preferences.hasAnyEnabled, isFalse);
    });

    test('saves and loads selected categories', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesNotificationSettingsStore();

      await store.save(
        const NotificationPreferences(
          categories: {SessionCategory.qualifying, SessionCategory.race},
        ),
      );
      final preferences = await store.load();

      expect(preferences.contains(SessionCategory.qualifying), isTrue);
      expect(preferences.contains(SessionCategory.race), isTrue);
      expect(preferences.contains(SessionCategory.practice), isFalse);
      expect(preferences.contains(SessionCategory.sprint), isFalse);
    });

    test('migrates legacy "all sessions" flag to every category', () async {
      SharedPreferences.setMockInitialValues({
        'notification_all_sessions_30m': true,
      });
      const store = SharedPreferencesNotificationSettingsStore();

      final preferences = await store.load();

      expect(preferences.categories, SessionCategory.values.toSet());
    });

    test('migrates legacy "race only" flag to race category', () async {
      SharedPreferences.setMockInitialValues({
        'notification_race_only_30m': true,
      });
      const store = SharedPreferencesNotificationSettingsStore();

      final preferences = await store.load();

      expect(preferences.categories, {SessionCategory.race});
    });

    test('new keys take precedence over legacy keys and clear them', () async {
      SharedPreferences.setMockInitialValues({
        // 레거시 켜짐 + 신형 레이스만 켜짐 → 신형 우선.
        'notification_all_sessions_30m': true,
        'notification_cat_race': true,
        'notification_cat_practice': false,
      });
      const store = SharedPreferencesNotificationSettingsStore();

      final loaded = await store.load();
      expect(loaded.categories, {SessionCategory.race});

      // 저장하면 레거시 키가 제거된다.
      await store.save(loaded);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('notification_all_sessions_30m'), isFalse);
      expect(prefs.containsKey('notification_race_only_30m'), isFalse);
    });
  });

  group('sessionCategoryOf', () {
    test('maps session ids to categories', () {
      expect(sessionCategoryOf('fp1'), SessionCategory.practice);
      expect(sessionCategoryOf('fp2'), SessionCategory.practice);
      expect(sessionCategoryOf('fp3'), SessionCategory.practice);
      expect(sessionCategoryOf('qualifying'), SessionCategory.qualifying);
      expect(sessionCategoryOf('sprint_qualifying'), SessionCategory.sprint);
      expect(sessionCategoryOf('sprint'), SessionCategory.sprint);
      expect(sessionCategoryOf('race'), SessionCategory.race);
      expect(sessionCategoryOf('unknown'), isNull);
    });
  });

  group('SessionNotificationPlanner', () {
    final planner = SessionNotificationPlanner();
    final now = DateTime.utc(2026, 6, 30);

    test('schedules every future session when all categories are on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: NotificationPreferences(
          categories: SessionCategory.values.toSet(),
        ),
        now: now,
      );

      expect(notifications, hasLength(5));
      expect(
        notifications.map((n) => n.sessionId),
        containsAll(['fp1', 'fp2', 'fp3', 'qualifying', 'race']),
      );
      expect(notifications.first.body, contains('7월 1일 10:00 (KST)'));
      expect(notifications.first.body, isNot(contains('30분 뒤')));
    });

    test('schedules only race session when only race category is on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(
          categories: {SessionCategory.race},
        ),
        now: now,
      );

      expect(notifications, hasLength(1));
      expect(notifications.single.sessionId, 'race');
      expect(notifications.single.category, SessionCategory.race);
      expect(notifications.single.title, '비아 포뮬러 레이스 알림');
    });

    test('schedules only practice sessions when only practice is on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(
          categories: {SessionCategory.practice},
        ),
        now: now,
      );

      expect(notifications.map((n) => n.sessionId), ['fp1', 'fp2', 'fp3']);
      expect(
        notifications.every((n) => n.category == SessionCategory.practice),
        isTrue,
      );
      expect(notifications.every((n) => n.title == '비아 포뮬러 세션 알림'), isTrue);
    });

    test('combines selected categories (practice + race)', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(
          categories: {SessionCategory.practice, SessionCategory.race},
        ),
        now: now,
      );

      expect(notifications.map((n) => n.sessionId), [
        'fp1',
        'fp2',
        'fp3',
        'race',
      ]);
    });

    test('excludes sessions whose reminder time has passed', () {
      final notifications = planner.buildSchedule(
        races: [_partlyPastRace()],
        preferences: NotificationPreferences(
          categories: SessionCategory.values.toSet(),
        ),
        now: now,
      );

      expect(notifications.map((n) => n.sessionId), ['race']);
    });

    test('excludes cancelled races', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace(isCancelled: true)],
        preferences: NotificationPreferences(
          categories: SessionCategory.values.toSet(),
        ),
        now: now,
      );

      expect(notifications, isEmpty);
    });

    test('limits notifications to next three grand prix', () {
      final races = _futureRaceWindow();

      final notifications = planner.buildSchedule(
        races: races,
        preferences: NotificationPreferences(
          categories: SessionCategory.values.toSet(),
        ),
        now: now,
      );

      expect(notifications, hasLength(15));
      expect(notifications.map((n) => n.raceId).toSet(), {
        'test-1-2026',
        'test-2-2026',
        'test-3-2026',
      });
      expect(notifications.any((n) => n.raceId == 'test-4-2026'), isFalse);
    });

    test('limits race-only notifications to next three grand prix', () {
      final races = _futureRaceWindow();

      final notifications = planner.buildSchedule(
        races: races,
        preferences: const NotificationPreferences(
          categories: {SessionCategory.race},
        ),
        now: now,
      );

      expect(notifications, hasLength(3));
      expect(notifications.every((n) => n.sessionId == 'race'), isTrue);
      expect(notifications.map((n) => n.raceId).toSet(), {
        'test-1-2026',
        'test-2-2026',
        'test-3-2026',
      });
    });
  });

  group('NotificationSettingsController', () {
    test('enabling a category schedules its sessions', () async {
      final store = _MemoryNotificationSettingsStore();
      final scheduler = _FakeScheduler();
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      final result = await controller.update(
        category: SessionCategory.race,
        enabled: true,
      );

      expect(result.preferences.contains(SessionCategory.race), isTrue);
      expect(result.scheduledCount, 1);
      expect(scheduler.scheduled.single.sessionId, 'race');
      expect(scheduler.cancelledIds, isNotEmpty);
    });

    test('categories accumulate across updates', () async {
      final store = _MemoryNotificationSettingsStore();
      final scheduler = _FakeScheduler();
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      await controller.update(category: SessionCategory.race, enabled: true);
      final result = await controller.update(
        category: SessionCategory.qualifying,
        enabled: true,
      );

      expect(result.preferences.categories, {
        SessionCategory.race,
        SessionCategory.qualifying,
      });
      expect(
        scheduler.scheduled.map((n) => n.sessionId),
        containsAll(['qualifying', 'race']),
      );
    });

    test('disabling a category reschedules the rest', () async {
      final store = _MemoryNotificationSettingsStore()
        ..preferences = const NotificationPreferences(
          categories: {SessionCategory.practice, SessionCategory.race},
        );
      final scheduler = _FakeScheduler();
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      final result = await controller.update(
        category: SessionCategory.practice,
        enabled: false,
      );

      expect(result.preferences.categories, {SessionCategory.race});
      expect(scheduler.scheduled.map((n) => n.sessionId), ['race']);
    });

    test('permission denial turns every category off', () async {
      final store = _MemoryNotificationSettingsStore();
      final scheduler = _FakeScheduler(permissionGranted: false);
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      final result = await controller.update(
        category: SessionCategory.race,
        enabled: true,
      );
      final saved = await store.load();

      expect(result.permissionDenied, isTrue);
      expect(result.preferences.hasAnyEnabled, isFalse);
      expect(saved.hasAnyEnabled, isFalse);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelledIds, isNotEmpty);
    });
  });
}

List<Race> _futureRaceWindow() {
  return [
    _futureRace(id: 'test-1-2026', round: 1, startDay: 1),
    _futureRace(id: 'test-2-2026', round: 2, startDay: 8),
    _futureRace(id: 'test-3-2026', round: 3, startDay: 15),
    _futureRace(id: 'test-4-2026', round: 4, startDay: 22),
  ];
}

Race _futureRace({
  int year = 2026,
  String id = 'test-2026',
  int round = 9,
  int startDay = 1,
  bool isCancelled = false,
}) {
  final raceDay = startDay + 2;
  return Race(
    id: id,
    round: round,
    nameKo: '테스트 그랑프리',
    nameEn: 'Test Grand Prix',
    countryKo: '대한민국',
    cityKo: '서울',
    circuitKo: '테스트 서킷',
    startDate: '$year-07-${_twoDigits(startDay)}',
    endDate: '$year-07-${_twoDigits(raceDay)}',
    hasSprint: false,
    status: RaceStatus.scheduled,
    isCancelled: isCancelled,
    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '7.$startDay 수',
        time: '10:00',
        fullDateTime: '7월 $startDay일 수요일 10:00',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '7.$startDay 수',
        time: '14:00',
        fullDateTime: '7월 $startDay일 수요일 14:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '7.${startDay + 1} 목',
        time: '10:00',
        fullDateTime: '7월 ${startDay + 1}일 목요일 10:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '7.${startDay + 1} 목',
        time: '14:00',
        fullDateTime: '7월 ${startDay + 1}일 목요일 14:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '7.$raceDay 금',
        time: '15:00',
        fullDateTime: '7월 $raceDay일 금요일 15:00',
      ),
    ],
  );
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

Race _partlyPastRace() {
  return const Race(
    id: 'partly-past-2026',
    round: 10,
    nameKo: '부분 종료 그랑프리',
    nameEn: 'Partly Past Grand Prix',
    countryKo: '대한민국',
    cityKo: '서울',
    circuitKo: '테스트 서킷',
    startDate: '2026-06-30',
    endDate: '2026-07-01',
    hasSprint: false,
    status: RaceStatus.scheduled,
    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '6.30 화',
        time: '09:20',
        fullDateTime: '6월 30일 화요일 09:20',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '7.1 수',
        time: '15:00',
        fullDateTime: '7월 1일 수요일 15:00',
      ),
    ],
  );
}

class _MemoryNotificationSettingsStore implements NotificationSettingsStore {
  NotificationPreferences preferences = const NotificationPreferences();

  @override
  Future<NotificationPreferences> load() async => preferences;

  @override
  Future<void> save(NotificationPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _FakeScheduler implements SessionNotificationScheduler {
  _FakeScheduler({this.permissionGranted = true});

  final bool permissionGranted;
  final scheduled = <ScheduledSessionNotification>[];
  final cancelledIds = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<void> cancelNotifications(Iterable<int> ids) async {
    cancelledIds.addAll(ids);
  }

  @override
  Future<void> schedule(
    List<ScheduledSessionNotification> notifications,
  ) async {
    scheduled
      ..clear()
      ..addAll(notifications);
  }
}
