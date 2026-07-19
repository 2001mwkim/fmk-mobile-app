import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  testWidgets('home hero shows countdown and full weekend schedule', (
    tester,
  ) async {
    await _pumpHome(tester, now: _beforeBritishSprint);

    // 히어로 v2: 카운트다운 3칸(DAYS/HRS/MIN)이 카드의 주인공.
    // 다음 세션 타일은 제거 — 세션 리스트 하이라이트가 그 역할을 한다.
    expect(find.text('DAYS'), findsOneWidget);
    expect(find.text('HRS'), findsOneWidget);
    expect(find.text('MIN'), findsOneWidget);
    expect(find.textContaining('다음 세션 · '), findsNothing);
    // 별도 '이번 주말 일정' 카드 대신 히어로 안에 전체 세션 리스트가 있다.
    expect(find.text('이번 주말 일정'), findsNothing);
    expect(find.text('레이스'), findsOneWidget); // 레이스 강조 행
    expect(find.text('한국 시간 (KST) 기준'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('home hero clamps countdown to zero while a session is live', (
    tester,
  ) async {
    // 스프린트 시작 시각 정각 — 다음 세션(라이브)의 시작이 지났으므로
    // 카운트다운은 00 00 00 으로 클램프되고 상태 뱃지가 '진행중'이 된다.
    await _pumpHome(tester, now: _duringBritishSprint);

    expect(find.text('진행중'), findsOneWidget); // 히어로 상태 뱃지
    expect(find.text('00'), findsNWidgets(3));
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
