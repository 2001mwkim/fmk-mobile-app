import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/live_session_controller.dart';
import 'package:fmk_app/services/live_session_service.dart';

void main() {
  test('LiveSessionController updates snapshot on successful fetch', () async {
    final now = DateTime(2026, 6, 30, 12);
    final snapshot = _liveSnapshot();
    final controller = LiveSessionController(
      _FakeLiveSessionService([LiveSessionFetchResult.success(snapshot)]),
      now: () => now,
    );

    await controller.refresh();

    expect(controller.snapshot, same(snapshot));
    expect(controller.isStale, isFalse);
    expect(controller.lastFetchedAt, now);
    expect(controller.lastSuccessAt, now);
  });

  test(
    'LiveSessionController keeps last snapshot briefly on fetch failure',
    () async {
      var now = DateTime(2026, 6, 30, 12);
      final snapshot = _liveSnapshot();
      final controller = LiveSessionController(
        _FakeLiveSessionService([
          LiveSessionFetchResult.success(snapshot),
          const LiveSessionFetchResult.failed(),
          const LiveSessionFetchResult.failed(),
        ]),
        now: () => now,
        gracePeriod: const Duration(seconds: 30),
        staleMaxAge: const Duration(seconds: 75),
      );

      await controller.refresh();
      now = now.add(const Duration(seconds: 60));
      await controller.refresh();

      expect(controller.snapshot, same(snapshot));
      expect(controller.isStale, isTrue);
      expect(controller.lastFetchedAt, now);

      now = now.add(const Duration(seconds: 20));
      await controller.refresh();

      expect(controller.snapshot, isNull);
      expect(controller.isStale, isFalse);
    },
  );

  test('keeps live snapshot when the next fetch fails within grace', () async {
    var now = DateTime(2026, 6, 30, 12);
    final live = _liveSnapshot();
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        LiveSessionFetchResult.success(live),
        const LiveSessionFetchResult.failed(),
      ]),
      now: () => now,
    );

    await controller.refresh();
    now = now.add(const Duration(minutes: 1)); // grace(3분) 이내
    await controller.refresh();

    expect(controller.snapshot, same(live));
    expect(controller.isStale, isFalse);
  });

  test('keeps live snapshot on successful null response', () async {
    var now = DateTime(2026, 6, 30, 12);
    final live = _liveSnapshot();
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        LiveSessionFetchResult.success(live),
        const LiveSessionFetchResult.success(null),
      ]),
      now: () => now,
    );

    await controller.refresh();
    now = now.add(const Duration(minutes: 1));
    await controller.refresh();

    expect(controller.snapshot, same(live));
    expect(controller.isStale, isFalse);
  });

  test(
    'keeps live snapshot on transient non-displayable, marks stale',
    () async {
      var now = DateTime(2026, 6, 30, 12);
      final live = _liveSnapshot();
      final controller = LiveSessionController(
        _FakeLiveSessionService([
          LiveSessionFetchResult.success(live),
          const LiveSessionFetchResult.success(
            LiveSessionSnapshot(
              status: LiveSessionStatus.inactive,
              updatedAt: '',
            ),
          ),
        ]),
        now: () => now,
      );

      await controller.refresh();
      now = now.add(const Duration(minutes: 5)); // grace 초과, max 이내
      await controller.refresh();

      expect(controller.snapshot, same(live));
      expect(controller.isStale, isTrue);
    },
  );

  test('drops live snapshot after staleMaxAge', () async {
    var now = DateTime(2026, 6, 30, 12);
    final live = _liveSnapshot();
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        LiveSessionFetchResult.success(live),
        const LiveSessionFetchResult.failed(),
      ]),
      now: () => now,
    );

    await controller.refresh();
    now = now.add(const Duration(minutes: 11)); // max(10분) 초과
    await controller.refresh();

    expect(controller.snapshot, isNull);
    expect(controller.isStale, isFalse);
  });

  test('shows ended snapshot while visibleUntil is valid', () async {
    final now = DateTime(2026, 6, 30, 12);
    final ended = LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '',
      visibleUntil: DateTime.now().add(const Duration(minutes: 25)),
      topThree: const [
        LiveDriverPosition(position: 1, code: 'NOR', displayName: 'NOR'),
      ],
    );
    final controller = LiveSessionController(
      _FakeLiveSessionService([LiveSessionFetchResult.success(ended)]),
      now: () => now,
    );

    await controller.refresh();
    expect(controller.snapshot, same(ended));
  });

  test(
    'waits for a repeated mid-race ended signal before showing final result',
    () async {
      final now = DateTime(2026, 6, 30, 12);
      const live = LiveSessionSnapshot(
        status: LiveSessionStatus.live,
        updatedAt: '2026-06-30T03:00:00Z',
        raceId: 'spain',
        sessionKey: 'race-1',
        sessionType: 'Race',
        sessionName: 'Race',
        currentLap: 24,
        totalLaps: 66,
      );
      final ended = LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-06-30T03:01:00Z',
        raceId: 'spain',
        sessionKey: 'race-1',
        sessionType: 'Race',
        sessionName: 'Race',
        currentLap: 24,
        totalLaps: 66,
        visibleUntil: DateTime.now().add(const Duration(minutes: 30)),
      );
      final controller = LiveSessionController(
        _FakeLiveSessionService([
          const LiveSessionFetchResult.success(live),
          LiveSessionFetchResult.success(ended),
          LiveSessionFetchResult.success(ended),
        ]),
        now: () => now,
      );

      await controller.refresh();
      await controller.refresh();
      expect(controller.snapshot, same(live));
      expect(controller.latestSessionSnapshot, same(live));

      await controller.refresh();
      expect(controller.snapshot, same(ended));
      expect(controller.latestSessionSnapshot, same(ended));
    },
  );

  test('accepts an ended signal immediately on the final lap', () async {
    final now = DateTime(2026, 6, 30, 12);
    const live = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-06-30T03:00:00Z',
      raceId: 'spain',
      sessionKey: 'race-1',
      sessionType: 'Race',
      sessionName: 'Race',
      currentLap: 65,
      totalLaps: 66,
    );
    final ended = LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '2026-06-30T03:01:00Z',
      raceId: 'spain',
      sessionKey: 'race-1',
      sessionType: 'Race',
      sessionName: 'Race',
      currentLap: 66,
      totalLaps: 66,
      visibleUntil: DateTime.now().add(const Duration(minutes: 30)),
    );
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        const LiveSessionFetchResult.success(live),
        LiveSessionFetchResult.success(ended),
      ]),
      now: () => now,
    );

    await controller.refresh();
    await controller.refresh();

    expect(controller.snapshot, same(ended));
    expect(controller.latestSessionSnapshot, same(ended));
  });

  test('hides ended snapshot once visibleUntil passed', () async {
    final now = DateTime(2026, 6, 30, 12);
    final live = _liveSnapshot();
    final expired = LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '',
      visibleUntil: DateTime.now().subtract(const Duration(minutes: 1)),
    );
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        LiveSessionFetchResult.success(live),
        LiveSessionFetchResult.success(expired),
      ]),
      now: () => now,
    );

    await controller.refresh();
    expect(controller.snapshot, same(live));
    await controller.refresh();
    expect(controller.snapshot, isNull); // 확정 종료 → 즉시 숨김
    // 내용 없는 종료 신호는 본문용 최근 세션을 덮어쓰지 않는다.
    expect(controller.latestSessionSnapshot, same(live));
    expect(controller.latestSessionIsStale, isFalse);
  });

  test(
    'live center keeps an expired ended session until a new session arrives',
    () async {
      final now = DateTime(2026, 6, 30, 12);
      final ended = LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-06-30T02:00:00Z',
        raceId: 'austria-2026',
        sessionType: 'Qualifying',
        sessionName: 'Qualifying',
        visibleUntil: now.subtract(const Duration(hours: 1)),
        classification: const [
          LiveDriverPosition(position: 1, code: 'NOR', displayName: '노리스'),
        ],
      );
      const preparing = LiveSessionSnapshot(
        status: LiveSessionStatus.inactive,
        updatedAt: '2026-06-30T11:58:00Z',
        raceId: 'austria-2026',
        sessionKey: 'race',
        sessionType: 'Race',
        sessionName: 'Race',
      );
      final controller = LiveSessionController(
        _FakeLiveSessionService([
          LiveSessionFetchResult.success(ended),
          const LiveSessionFetchResult.success(preparing),
        ]),
        now: () => now,
      );

      await controller.refresh();
      expect(controller.snapshot, isNull);
      expect(controller.latestSessionSnapshot, same(ended));

      await controller.refresh();
      expect(controller.latestSessionSnapshot, same(preparing));
    },
  );

  test('lastSession is promoted to the live center on a cold start', () async {
    final now = DateTime(2026, 6, 30, 12);
    final last = LiveLastSession(
      raceId: 'austria-2026',
      sessionType: 'Practice',
      sessionName: 'Practice 1',
      endedAt: now.subtract(const Duration(hours: 2)),
      classification: const [
        LiveDriverPosition(position: 1, code: 'NOR', displayName: '노리스'),
      ],
    );
    final wrapper = LiveSessionSnapshot(
      status: LiveSessionStatus.inactive,
      updatedAt: '',
      lastSession: last,
    );
    final controller = LiveSessionController(
      _FakeLiveSessionService([LiveSessionFetchResult.success(wrapper)]),
      now: () => now,
    );

    await controller.refresh();

    expect(controller.snapshot, isNull);
    expect(controller.latestSessionSnapshot?.status, LiveSessionStatus.ended);
    expect(controller.latestSessionSnapshot?.sessionName, 'Practice 1');
    expect(controller.latestSessionSnapshot?.classification.single.code, 'NOR');
  });

  test('widget bridge keeps live payload through a transient null', () async {
    var now = DateTime(2026, 6, 30, 12);
    final live = _liveSnapshot();
    final controller = LiveSessionController(
      _FakeLiveSessionService([
        LiveSessionFetchResult.success(live),
        const LiveSessionFetchResult.success(null),
      ]),
      now: () => now,
    );

    await controller.refresh();
    now = now.add(const Duration(minutes: 1));
    await controller.refresh();

    // 컨트롤러가 마지막 스냅샷을 유지하므로 위젯도 default 로 돌아가지 않는다.
    final payload = buildFmkHomeWidgetPayload(
      snapshot: controller.snapshot,
      now: now,
    );
    expect(payload.mode, 'live');
  });

  test(
    'LiveSessionController keeps null when fetch fails without snapshot',
    () async {
      final now = DateTime(2026, 6, 30, 12);
      final controller = LiveSessionController(
        _FakeLiveSessionService([const LiveSessionFetchResult.failed()]),
        now: () => now,
      );

      await controller.refresh();

      expect(controller.snapshot, isNull);
      expect(controller.isStale, isFalse);
      expect(controller.lastFetchedAt, now);
      expect(controller.lastSuccessAt, isNull);
    },
  );

  test(
    'LiveSessionController clears expired snapshots instead of retaining',
    () async {
      final now = DateTime(2026, 6, 30, 12);
      final live = _liveSnapshot();
      final expired = LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-06-30T04:34:00.000Z',
        visibleUntil: DateTime.now().subtract(const Duration(minutes: 1)),
        topThree: live.topThree,
        classification: live.classification,
      );
      final controller = LiveSessionController(
        _FakeLiveSessionService([
          LiveSessionFetchResult.success(live),
          LiveSessionFetchResult.success(expired),
        ]),
        now: () => now,
      );

      await controller.refresh();
      expect(controller.snapshot, same(live));

      await controller.refresh();
      expect(controller.snapshot, isNull);
      expect(controller.isStale, isFalse);
    },
  );
}

LiveSessionSnapshot _liveSnapshot() {
  return const LiveSessionSnapshot(
    status: LiveSessionStatus.live,
    updatedAt: '2026-06-30T04:34:00.000Z',
    raceId: 'spain',
    raceName: '스페인 그랑프리',
    sessionType: 'Race',
    sessionName: '레이스',
    currentLap: 42,
    totalLaps: 66,
    topThree: [
      LiveDriverPosition(position: 1, code: 'NOR', displayName: '랜도 노리스'),
      LiveDriverPosition(
        position: 2,
        code: 'PIA',
        displayName: '오스카 피아스트리',
        interval: '+2.341',
      ),
      LiveDriverPosition(
        position: 3,
        code: 'LEC',
        displayName: '샤를 르클레르',
        interval: '+5.118',
      ),
    ],
    classification: [
      LiveDriverPosition(position: 1, code: 'NOR', displayName: '랜도 노리스'),
      LiveDriverPosition(
        position: 2,
        code: 'PIA',
        displayName: '오스카 피아스트리',
        interval: '+2.341',
      ),
    ],
  );
}

class _FakeLiveSessionService extends LiveSessionService {
  _FakeLiveSessionService(this.results) : super(url: 'test://live');

  final List<LiveSessionFetchResult> results;
  int _calls = 0;

  @override
  Future<LiveSessionFetchResult> fetchResult() async {
    final index = _calls++;
    if (index >= results.length) return const LiveSessionFetchResult.failed();
    return results[index];
  }
}
