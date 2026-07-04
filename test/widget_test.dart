import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';
import 'package:fmk_app/data/live_session_mock.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/live_session_controller.dart';
import 'package:fmk_app/services/live_session_service.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/home_live_top_three_card.dart';
import 'package:fmk_app/widgets/race_live_classification_panel.dart';

void main() {
  testWidgets('bottom tabs, race detail, and settings navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('2026 시즌'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('일정'), findsOneWidget);
    expect(find.text('순위'), findsOneWidget);
    expect(find.text('직관'), findsOneWidget);
    // 히어로 상태 칩은 시점에 따라 '다음 그랑프리' 또는 '진행중'으로 표시된다.
    expect(
      find.text('다음 그랑프리').evaluate().isNotEmpty ||
          find.text('진행중').evaluate().isNotEmpty,
      isTrue,
    );
    // 다음 세션 정보는 히어로 카드 내부 세션 박스로 통합됨(별도 카드 제거).
    await tester.scrollUntilVisible(find.text('이번 주말 일정'), 200);
    expect(find.text('이번 주말 일정'), findsOneWidget);

    await tester.tap(find.text('일정'));
    await tester.pumpAndSettle();
    expect(find.text('시즌 캘린더'), findsOneWidget);
    expect(find.text('다가오는 그랑프리'), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('예정'), findsWidgets);
    expect(find.text('진행중'), findsWidgets);
    expect(find.text('종료'), findsWidgets);

    await tester.tap(find.text('종료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호주 그랑프리'));
    await tester.pumpAndSettle();
    expect(find.text('일정으로'), findsOneWidget);
    expect(find.text('레이스 결과'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('레이스 시작'), 200);
    expect(find.text('레이스 시작'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('세션 일정'), 200);
    expect(find.text('세션 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('서킷 정보'), 200);
    expect(find.text('서킷 정보'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Circuit layouts: F1DB (CC BY 4.0)'),
      200,
    );
    expect(find.text('Circuit layouts: F1DB (CC BY 4.0)'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('순위'));
    await tester.pumpAndSettle();
    expect(find.text('챔피언십 순위'), findsOneWidget);
    expect(find.text('키미 안토넬리'), findsOneWidget);
    await tester.tap(find.text('컨스트럭터'));
    await tester.pumpAndSettle();
    expect(find.text('키미 안토넬리'), findsNothing);
    expect(find.text('메르세데스'), findsWidgets);

    await tester.tap(find.text('직관'));
    await tester.pumpAndSettle();
    expect(find.text('직관 가이드'), findsWidgets);
    expect(find.text('GUIDE IN PROGRESS'), findsOneWidget);
    expect(find.text('아시아 그랑프리 직관 정보 준비 중'), findsOneWidget);
    expect(find.text('일본 그랑프리'), findsOneWidget);
    expect(find.text('중국 그랑프리'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('싱가포르 그랑프리'), 200);
    expect(find.text('싱가포르 그랑프리'), findsOneWidget);
    expect(find.text('관련 그랑프리'), findsWidgets);
    expect(find.text('직관 정보 준비 중'), findsWidgets);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView).first, const Offset(0, 800), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsWidgets);
    expect(find.text('일정 관리'), findsNothing);
    expect(find.text('캘린더에 추가'), findsNothing);
    expect(find.text('알림 설정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('인스타그램 보러가기'), 200);
    expect(find.text('인스타그램 보러가기'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('F1DB · CC BY 4.0'), 200);
    expect(find.text('F1DB · CC BY 4.0'), findsOneWidget);
  });

  testWidgets('live widgets render and expand with mock snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              HomeLiveTopThreeCard(snapshot: mockLiveSession),
              RaceLiveClassificationPanel(
                snapshot: mockLiveSession,
                raceId: 'spain',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('스페인 그랑프리'), findsOneWidget);
    expect(find.text('전체 순위 보기'), findsOneWidget);
    expect(find.text('현재 레이스 순위'), findsOneWidget);

    await tester.ensureVisible(find.text('4위 이하 순위 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4위 이하 순위 보기'));
    await tester.pumpAndSettle();
    expect(find.text('순위 접기'), findsOneWidget);
    expect(find.text('막스 베르스타펜'), findsWidgets);
  });

  testWidgets('home hero session box uses matching live snapshot', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      now: _beforeBritishSprint,
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.live,
        raceId: 'great-britain-2026',
      ),
    );

    expect(find.text('진행중인 세션'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('42 / 53 LAP'), findsOneWidget);
  });

  testWidgets('home hero ignores live snapshot for another race', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      now: _beforeBritishSprint,
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.live,
        raceId: 'spain',
      ),
    );

    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('진행중인 세션'), findsNothing);
  });

  testWidgets('home hero shows recent state for matching ended snapshot', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      now: _beforeBritishSprint,
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'great-britain-2026',
        visibleUntil: DateTime.now().add(const Duration(minutes: 25)),
      ),
    );

    expect(find.text('최근 종료된 세션'), findsOneWidget);
    expect(find.text('RESULT'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
  });

  testWidgets('home hero keeps qualifying live between Q segments', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      now: DateTime.parse('2026-07-05T00:20:00+09:00'),
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'great-britain-2026',
        sessionType: 'Qualifying',
        sessionName: 'Qualifying',
        endedAt: DateTime.parse('2026-07-04T15:18:00Z'),
      ),
    );

    expect(find.text('진행중인 세션'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('최근 종료된 세션'), findsNothing);
    expect(find.text('RESULT'), findsNothing);
  });

  testWidgets('home hero falls back to next session for expired snapshot', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      now: _beforeBritishSprint,
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'great-britain-2026',
        visibleUntil: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('최근 종료된 세션'), findsNothing);
  });

  testWidgets('home hero falls back to next session without live snapshot', (
    tester,
  ) async {
    await _pumpHome(tester, now: _beforeBritishSprint);

    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('진행중인 세션'), findsNothing);
  });

  testWidgets('home hero uses schedule live status when snapshot is absent', (
    tester,
  ) async {
    await _pumpHome(tester, now: _duringBritishSprint);

    expect(find.text('진행중인 세션'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });

  test('parseLiveJson maps collector live.json into a snapshot', () {
    const body = '''
{
  "snapshot": {
    "status": "live",
    "mode": "live-candidate",
    "raceId": "spain",
    "raceName": "스페인 그랑프리",
    "sessionType": "Race",
    "sessionName": "레이스",
    "currentLap": 42,
    "totalLaps": 66,
    "updatedAt": "2026-06-30T13:34:56.000Z",
    "topThree": [
      {"position": 1, "racingNumber": "4", "code": "NOR", "displayName": "랜도 노리스", "source": "top-three"},
      {"position": 2, "racingNumber": "81", "code": "PIA", "displayName": "오스카 피아스트리", "interval": "+2.341", "source": "top-three"},
      {"position": 3, "racingNumber": "16", "code": "LEC", "displayName": "샤를 르클레르", "interval": "+5.118", "source": "top-three"}
    ],
    "classification": [
      {"position": 1, "racingNumber": "4", "code": "NOR", "displayName": "랜도 노리스", "gapToLeader": null, "source": "timing-data"},
      {"position": 2, "racingNumber": "81", "code": "PIA", "displayName": "오스카 피아스트리", "interval": "+2.341", "source": "timing-data"}
    ]
  },
  "collector": {"feedUpdates": 10}
}
''';

    final snapshot = parseLiveJson(body);
    expect(snapshot, isNotNull);
    expect(snapshot!.status, LiveSessionStatus.live);
    expect(snapshot.raceId, 'spain');
    expect(snapshot.currentLap, 42);
    expect(snapshot.totalLaps, 66);
    expect(snapshot.isRaceOrSprint, isTrue);
    expect(snapshot.topThree.length, 3);
    expect(snapshot.topThree.first.code, 'NOR');
    expect(snapshot.classification.length, 2);
    // interval 우선(race) 갭 규칙
    expect(snapshot.topThree[1].gap(raceLike: true), '+2.341');

    // 잘못된 본문은 null (앱 크래시 방지)
    expect(parseLiveJson('not json'), isNull);
    expect(parseLiveJson('{"snapshot": 123}'), isNull);
  });

  test('ended within 30min is displayable, expired is hidden', () {
    final now = DateTime.now();
    LiveSessionSnapshot ended(DateTime visibleUntil) => LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '',
      visibleUntil: visibleUntil,
    );

    expect(ended(now.add(const Duration(minutes: 25))).isDisplayable, isTrue);
    expect(
      ended(now.subtract(const Duration(minutes: 10))).isDisplayable,
      isFalse,
    );
    // visibleUntil 이 없으면 미표시
    expect(
      const LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '',
      ).isDisplayable,
      isFalse,
    );
  });

  test('updatedAtLabel formats KST (UTC+9)', () {
    const live = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-06-30T04:34:00.000Z',
    );
    expect(live.updatedAtLabel, '업데이트 13:34 KST');

    const empty = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '',
    );
    expect(empty.updatedAtLabel, isNull);
  });

  test('liveCountryFlag maps raceId to a flag, safe on miss', () {
    expect(liveCountryFlag('japan-2026'), '🇯🇵');
    expect(liveCountryFlag('does-not-exist'), isNull);
    expect(liveCountryFlag(null), isNull);
  });

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

  testWidgets('home live card tap navigates to the matching race detail', (
    tester,
  ) async {
    final race = getRaceById('japan-2026')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ListView(
              children: [
                HomeLiveTopThreeCard(
                  snapshot: mockLiveSession,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RaceDetailScreen(race: race),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('전체 순위 보기'));
    await tester.pumpAndSettle();
    // 상세 화면 진입 확인(앱바/히어로에 그랑프리명 노출)
    expect(find.text('일본 그랑프리'), findsWidgets);
  });
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

final DateTime _beforeBritishSprint = DateTime.parse(
  '2026-07-04T12:00:00+09:00',
);
final DateTime _duringBritishSprint = DateTime.parse(
  '2026-07-04T20:30:00+09:00',
);

Future<void> _pumpHome(
  WidgetTester tester, {
  required DateTime now,
  LiveSessionSnapshot? snapshot,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: HomeScreen(nowOverride: now, liveSnapshotOverride: snapshot),
    ),
  );
  await tester.pump();
}

LiveSessionSnapshot _homeHeroSnapshot({
  required LiveSessionStatus status,
  required String raceId,
  DateTime? visibleUntil,
  DateTime? endedAt,
  String sessionType = 'Race',
  String sessionName = '레이스',
}) {
  return LiveSessionSnapshot(
    status: status,
    updatedAt: '2026-07-04T11:30:00.000Z',
    raceId: raceId,
    raceName: '영국 그랑프리',
    sessionType: sessionType,
    sessionName: sessionName,
    currentLap: 42,
    totalLaps: 53,
    endedAt: endedAt,
    visibleUntil: visibleUntil,
    topThree: const [
      LiveDriverPosition(position: 1, code: 'NOR', displayName: '랜도 노리스'),
      LiveDriverPosition(position: 2, code: 'PIA', displayName: '오스카 피아스트리'),
      LiveDriverPosition(position: 3, code: 'LEC', displayName: '샤를 르클레르'),
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
