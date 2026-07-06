import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/live_session_mock.dart';
import 'package:fmk_app/data/race_results.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/home_live_top_three_card.dart';
import 'package:fmk_app/widgets/race_live_classification_panel.dart';
import 'package:fmk_app/widgets/race_result_classification_panel.dart';

void main() {
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
    expect(find.text('+2.341'), findsWidgets);

    await tester.ensureVisible(find.text('4위 이하 순위 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4위 이하 순위 보기'));
    await tester.pumpAndSettle();
    expect(find.text('순위 접기'), findsOneWidget);
    expect(find.text('막스 베르스타펜'), findsWidgets);
  });

  testWidgets('practice and qualifying live widgets show lap times', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              HomeLiveTopThreeCard(snapshot: mockQualifyingLiveSession),
              RaceLiveClassificationPanel(
                snapshot: mockQualifyingLiveSession,
                raceId: 'spain',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('LAP'), findsOneWidget);
    expect(find.text('1:28.493'), findsWidgets);
    expect(find.text('1:28.626'), findsWidgets);
    expect(find.text('+2.341'), findsNothing);
  });

  testWidgets('race result panel shows podium and expands full order', (
    tester,
  ) async {
    final results = getRaceResults('australia-2026')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [RaceResultClassificationPanel(results: results)],
          ),
        ),
      ),
    );

    expect(find.text('레이스 결과'), findsOneWidget);
    expect(find.text('${results.length} DRIVERS'), findsOneWidget);
    // 포디움 3명 + 갭/총시간 표기.
    expect(find.text('조지 러셀'), findsOneWidget);
    expect(find.text('1:23:06.801'), findsOneWidget);
    expect(find.text('+2.974'), findsOneWidget);
    // 4위 이하는 접혀 있다가 확장 시 노출.
    expect(find.text('루이스 해밀턴'), findsNothing);
    await tester.tap(find.text('4위 이하 순위 보기'));
    await tester.pumpAndSettle();
    expect(find.text('순위 접기'), findsOneWidget);
    expect(find.text('루이스 해밀턴'), findsOneWidget);
  });

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
