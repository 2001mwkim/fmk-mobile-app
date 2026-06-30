import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/app.dart';
import 'package:fmk_app/data/live_session_mock.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/home_live_top_three_card.dart';
import 'package:fmk_app/widgets/race_live_classification_panel.dart';

void main() {
  testWidgets('bottom tabs, race detail, and settings navigation work', (
    tester,
  ) async {
    await tester.pumpWidget(const FmkApp());

    expect(find.text('포매코'), findsOneWidget);
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
    expect(find.text('다음 세션'), findsOneWidget);
    expect(find.text('이번 주말 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('시즌 진행 상황'), 200);
    expect(find.text('시즌 진행 상황'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('전체 일정 보기'), 200);
    expect(find.text('전체 일정 보기'), findsOneWidget);

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
    await tester.pageBack();
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
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('설정'), findsWidgets);
    expect(find.text('일정 관리'), findsOneWidget);
    expect(find.text('캘린더에 추가'), findsOneWidget);
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
}
