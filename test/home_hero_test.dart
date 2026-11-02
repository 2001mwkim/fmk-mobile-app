import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/home_live_top_three_card.dart';

void main() {
  testWidgets('home hero shows countdown and full weekend schedule', (
    tester,
  ) async {
    await _pumpHome(tester, now: _beforeBritishSprint);

    // 카운트다운("○○ 시작까지 / N일 N시간 N분")이 카드의 주인공.
    // 영문 DAYS/HRS/MIN 라벨은 2026-10 디자인 정리에서 한글 단위로 바꿨다.
    expect(find.byKey(const ValueKey('home-countdown')), findsOneWidget);
    expect(find.textContaining('시작까지'), findsOneWidget);
    // 일·시간·분 세 칸('일'은 세션 목록의 일요일과 겹쳐 카운트다운 안에서만 찾는다).
    Finder inCountdown(String text) => find.descendant(
      of: find.byKey(const ValueKey('home-countdown')),
      matching: find.text(text),
    );
    expect(inCountdown('일'), findsOneWidget);
    expect(inCountdown('시간'), findsOneWidget);
    expect(inCountdown('분'), findsOneWidget);
    expect(inCountdown('초'), findsNothing); // 초 단위는 사용자 결정으로 뺐다
    expect(find.text('DAYS'), findsNothing);
    expect(find.textContaining('다음 세션 · '), findsNothing);
    // 별도 '이번 주말 일정' 카드 대신 히어로 안에 전체 세션 리스트가 있다.
    expect(find.text('이번 주말 일정'), findsNothing);
    expect(find.text('레이스'), findsOneWidget); // 레이스 강조 행
    expect(find.text('한국 시간 (KST) 기준'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('home hero shows live state instead of a zero countdown', (
    tester,
  ) async {
    // 스프린트 시작 시각 정각 — 다음 세션(라이브)의 시작이 지났으므로
    // 0 0 0 카운트다운 대신 '진행중'을 보여준다(주말 캡션은 '이번 주말').
    await _pumpHome(tester, now: _duringBritishSprint);

    expect(find.text('진행중'), findsOneWidget);
    expect(find.text('이번 주말'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-countdown')), findsNothing);
  });

  testWidgets('home hero moves to next GP when live data marks race ended', (
    tester,
  ) async {
    // 레이스가 스케줄 종료 창(23:00+2h=01:00)보다 일찍 끝난 상황(00:31 체커기).
    await _pumpHome(
      tester,
      now: DateTime.parse('2026-07-06T00:40:00+09:00'),
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'great-britain-2026',
        endedAt: DateTime.parse('2026-07-05T15:31:00Z'),
      ),
    );

    // 히어로가 끝난 영국 GP를 '진행중'으로 붙잡지 않고 다음 GP로 넘어간다.
    expect(find.text('벨기에 그랑프리'), findsOneWidget);
    expect(find.text('진행중'), findsNothing);
  });

  testWidgets('home hero keeps current GP on pre-race fake ended snapshot', (
    tester,
  ) async {
    // F1 피드가 퀄리 종료 후 SessionInfo 를 미리 Race 로 바꿔, 일요일 낮에
    // 'ended Race' 스냅샷이 오는 상황 — 레이스 시작 전이므로 넘기지 않는다.
    await _pumpHome(
      tester,
      now: DateTime.parse('2026-07-19T15:00:00+09:00'),
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'belgium-2026',
      ),
    );

    // 라이브 카드도 GP명을 표시하므로 히어로까지 최소 1개 이상이면 된다.
    expect(find.text('벨기에 그랑프리'), findsWidgets);
    expect(find.text('헝가리 그랑프리'), findsNothing);
  });

  testWidgets('tapping an ended session card opens the live center tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedLiveCenter = false;
    await _pumpHome(
      tester,
      now: DateTime.parse('2026-07-05T18:00:00Z'),
      snapshot: _homeHeroSnapshot(
        status: LiveSessionStatus.ended,
        raceId: 'great-britain-2026',
        endedAt: DateTime.parse('2026-07-05T17:30:00Z'),
      ),
      onOpenLiveCenter: () => openedLiveCenter = true,
    );

    await tester.tap(find.byType(HomeLiveTopThreeCard));
    await tester.pump();

    expect(openedLiveCenter, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
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
  VoidCallback? onOpenLiveCenter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: HomeScreen(
        nowOverride: now,
        liveSnapshotOverride: snapshot,
        onOpenLiveCenter: onOpenLiveCenter,
      ),
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
