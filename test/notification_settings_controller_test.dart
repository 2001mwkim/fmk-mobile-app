import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/race.dart';
import 'package:fmk_app/models/race_session.dart';
import 'package:fmk_app/services/notification_service.dart';
import 'package:fmk_app/services/notification_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Notification settings store', () {
    test('defaults to all notifications off', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesNotificationSettingsStore();

      final preferences = await store.load();

      expect(preferences.allSessions30m, isFalse);
      expect(preferences.raceOnly30m, isFalse);
    });

    test('saves and loads notification settings', () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesNotificationSettingsStore();

      await store.save(
        const NotificationPreferences(allSessions30m: true, raceOnly30m: true),
      );
      final preferences = await store.load();

      expect(preferences.allSessions30m, isTrue);
      expect(preferences.raceOnly30m, isTrue);
    });
  });

  group('SessionNotificationPlanner', () {
    final planner = SessionNotificationPlanner();
    final now = DateTime.utc(2026, 6, 30);

    test('schedules every future session when all sessions is on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(allSessions30m: true),
        now: now,
      );

      expect(notifications, hasLength(5));
      expect(
        notifications.map((n) => n.sessionId),
        containsAll(['fp1', 'fp2', 'fp3', 'qualifying', 'race']),
      );
      expect(
        notifications.every(
          (n) => n.kind == ScheduledNotificationKind.allSession,
        ),
        isTrue,
      );
      expect(notifications.first.body, contains('7월 1일 10:00 (KST)'));
      expect(notifications.first.body, isNot(contains('30분 뒤')));
    });

    test('schedules only race session when race only is on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(raceOnly30m: true),
        now: now,
      );

      expect(notifications, hasLength(1));
      expect(notifications.single.sessionId, 'race');
      expect(notifications.single.title, '비아 포뮬러 레이스 알림');
    });

    test('does not duplicate race when both options are on', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace()],
        preferences: const NotificationPreferences(
          allSessions30m: true,
          raceOnly30m: true,
        ),
        now: now,
      );

      expect(notifications, hasLength(5));
      expect(notifications.where((n) => n.sessionId == 'race'), hasLength(1));
      expect(
        notifications.singleWhere((n) => n.sessionId == 'race').kind,
        ScheduledNotificationKind.allSession,
      );
    });

    test('excludes sessions whose reminder time has passed', () {
      final notifications = planner.buildSchedule(
        races: [_partlyPastRace()],
        preferences: const NotificationPreferences(allSessions30m: true),
        now: now,
      );

      expect(notifications.map((n) => n.sessionId), ['race']);
    });

    test('excludes cancelled races', () {
      final notifications = planner.buildSchedule(
        races: [_futureRace(isCancelled: true)],
        preferences: const NotificationPreferences(allSessions30m: true),
        now: now,
      );

      expect(notifications, isEmpty);
    });

    test('limits all session notifications to next three grand prix', () {
      final races = _futureRaceWindow();

      final notifications = planner.buildSchedule(
        races: races,
        preferences: const NotificationPreferences(allSessions30m: true),
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

    test('limits race only notifications to next three grand prix', () {
      final races = _futureRaceWindow();

      final notifications = planner.buildSchedule(
        races: races,
        preferences: const NotificationPreferences(raceOnly30m: true),
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

    test('limits both toggles to next three grand prix without duplicates', () {
      final races = _futureRaceWindow();

      final notifications = planner.buildSchedule(
        races: races,
        preferences: const NotificationPreferences(
          allSessions30m: true,
          raceOnly30m: true,
        ),
        now: now,
      );

      expect(notifications, hasLength(15));
      expect(notifications.where((n) => n.sessionId == 'race'), hasLength(3));
      expect(
        notifications.every(
          (n) => n.kind == ScheduledNotificationKind.allSession,
        ),
        isTrue,
      );
      expect(notifications.map((n) => n.raceId).toSet(), {
        'test-1-2026',
        'test-2-2026',
        'test-3-2026',
      });
    });
  });

  group('NotificationSettingsController', () {
    test('updates and schedules all session notifications', () async {
      final store = _MemoryNotificationSettingsStore();
      final scheduler = _FakeScheduler();
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      final result = await controller.update(allSessions30m: true);

      expect(result.preferences.allSessions30m, isTrue);
      expect(result.scheduledCount, 5);
      expect(scheduler.scheduled.map((n) => n.sessionId), hasLength(5));
      expect(scheduler.cancelledIds, isNotEmpty);
    });

    test('permission denial turns toggles back off', () async {
      final store = _MemoryNotificationSettingsStore();
      final scheduler = _FakeScheduler(permissionGranted: false);
      final controller = NotificationSettingsController(
        store: store,
        scheduler: scheduler,
        races: [_futureRace()],
        now: () => DateTime.utc(2026, 6, 30),
      );

      final result = await controller.update(raceOnly30m: true);
      final saved = await store.load();

      expect(result.permissionDenied, isTrue);
      expect(result.preferences.allSessions30m, isFalse);
      expect(result.preferences.raceOnly30m, isFalse);
      expect(saved.allSessions30m, isFalse);
      expect(saved.raceOnly30m, isFalse);
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
    startDate: '2026-07-${_twoDigits(startDay)}',
    endDate: '2026-07-${_twoDigits(raceDay)}',
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
