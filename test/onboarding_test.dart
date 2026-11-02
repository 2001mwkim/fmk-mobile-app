import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/screens/onboarding_screen.dart';
import 'package:fmk_app/services/my_picks_controller.dart';
import 'package:fmk_app/services/notification_service.dart';
import 'package:fmk_app/services/notification_settings_controller.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoStandings implements StandingsRepository {
  const _NoStandings();
  @override
  Future<StandingsSnapshot?> fetchLatest() async => null;
}

class _MemoryStore implements NotificationSettingsStore {
  NotificationPreferences preferences = const NotificationPreferences();
  @override
  Future<NotificationPreferences> load() async => preferences;
  @override
  Future<void> save(NotificationPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _Scheduler implements SessionNotificationScheduler {
  _Scheduler({this.granted = true});
  final bool granted;
  int permissionRequests = 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> cancelNotifications(Iterable<int> ids) async {}
  @override
  Future<void> schedule(List<ScheduledSessionNotification> n) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<({_MemoryStore store, _Scheduler scheduler, MyPicksController picks})>
  pump(WidgetTester tester, {bool granted = true}) async {
    final store = _MemoryStore();
    final scheduler = _Scheduler(granted: granted);
    final picks = MyPicksController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OnboardingScreen(
                    picksController: picks,
                    notificationController: NotificationSettingsController(
                      store: store,
                      scheduler: scheduler,
                      races: const [],
                    ),
                    standingsRepository: const _NoStandings(),
                    onPicksChanged: () async {},
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (store: store, scheduler: scheduler, picks: picks);
  }

  testWidgets('소개 → MY DRIVER 선택 → 알림 켜기까지 끝나면 닫힌다', (tester) async {
    final env = await pump(tester);
    expect(find.text('비아 포뮬러'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('누구를 응원하세요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-pick-driver')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-driver-LEC')));
    await tester.pumpAndSettle();
    expect(env.picks.picks.driverCode, 'LEC');
    expect(find.text('샤를 르클레르'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('세션을 놓치지 않게'), findsOneWidget);

    // 기본값(퀄리·레이스)에 프랙티스를 더하고 15분 전으로.
    await tester.tap(find.widgetWithText(FilterChip, '프랙티스'));
    await tester.tap(find.text('15분 전'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림 켜고 시작하기'));
    await tester.pumpAndSettle();

    expect(env.store.preferences.categories, {
      SessionCategory.practice,
      SessionCategory.qualifying,
      SessionCategory.race,
    });
    expect(env.store.preferences.leadMinutes, 15);
    expect(env.scheduler.permissionRequests, 1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('건너뛰기는 아무것도 저장하지 않고 닫는다', (tester) async {
    final env = await pump(tester);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(env.store.preferences.hasAnyEnabled, isFalse);
    expect(env.scheduler.permissionRequests, 0);
  });

  testWidgets('권한이 거부되면 안내하고 그래도 닫는다', (tester) async {
    final env = await pump(tester, granted: false);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('알림 켜고 시작하기'));
    await tester.pumpAndSettle();
    expect(env.store.preferences.hasAnyEnabled, isFalse);
    expect(find.textContaining('알림 권한이 꺼져 있어요'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });
}
