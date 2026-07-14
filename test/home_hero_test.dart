import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
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

    // 히어로 v2: 라이브 상태는 카운트다운 옆 하이라이트 타일이 표현한다.
    expect(find.textContaining('진행중 · '), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
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

    expect(find.textContaining('다음 세션 · '), findsOneWidget);
    expect(find.textContaining('진행중 · '), findsNothing);
  });

  testWidgets('home hero shows next session instead of ended snapshot', (
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

    // 종료된 세션 결과는 타일에 띄우지 않고 다음 세션으로 대체한다.
    expect(find.textContaining('다음 세션 · '), findsOneWidget);
    expect(find.text('최근 종료된 세션'), findsNothing);
    expect(find.text('RESULT'), findsNothing);
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

    expect(find.textContaining('진행중 · '), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('최근 종료된 세션'), findsNothing);
    expect(find.text('RESULT'), findsNothing);
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
    expect(find.textContaining('진행중 · '), findsNothing);
    expect(find.textContaining('다음 세션 · '), findsOneWidget);
    expect(find.text('벨기에 그랑프리'), findsOneWidget);
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

    expect(find.textContaining('다음 세션 · '), findsOneWidget);
    expect(find.text('최근 종료된 세션'), findsNothing);
  });

  testWidgets('home hero falls back to next session without live snapshot', (
    tester,
  ) async {
    await _pumpHome(tester, now: _beforeBritishSprint);

    expect(find.textContaining('다음 세션 · '), findsOneWidget);
    expect(find.textContaining('진행중 · '), findsNothing);
  });

  testWidgets('home hero shows countdown and full weekend schedule', (
    tester,
  ) async {
    await _pumpHome(tester, now: _beforeBritishSprint);

    // 히어로 v2: 카운트다운 3칸(DAYS/HRS/MIN)이 카드의 주인공.
    expect(find.text('DAYS'), findsOneWidget);
    expect(find.text('HRS'), findsOneWidget);
    expect(find.text('MIN'), findsOneWidget);
    // 별도 '이번 주말 일정' 카드 대신 히어로 안에 전체 세션 리스트가 있다.
    expect(find.text('이번 주말 일정'), findsNothing);
    expect(find.text('레이스'), findsOneWidget); // 레이스 강조 행
    expect(find.text('한국 시간 (KST) 기준'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('home hero uses schedule live status when snapshot is absent', (
    tester,
  ) async {
    await _pumpHome(tester, now: _duringBritishSprint);

    expect(find.textContaining('진행중 · '), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
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
