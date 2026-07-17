import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/live_center_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  testWidgets('종료 세션은 별도 최근 결과 카드 없이 라이브센터 본문에 표시된다', (tester) async {
    const ended = LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '2026-07-17T10:00:00Z',
      raceName: 'British Grand Prix',
      sessionType: 'Qualifying',
      sessionName: 'Qualifying',
      classification: [
        LiveDriverPosition(
          position: 1,
          code: 'NOR',
          displayName: '랜도 노리스',
          displayTime: '1:25.123',
        ),
      ],
      raceControlMessages: [LiveRaceControlMessage(message: 'SESSION ENDED')],
      weather: LiveWeather(airTemperature: 21.5),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: ended),
      ),
    );

    expect(find.text('최종 결과'), findsOneWidget);
    expect(find.text('NOR'), findsOneWidget);
    expect(find.text('SESSION ENDED'), findsOneWidget);
    expect(find.text('21.5°'), findsOneWidget);
    expect(find.textContaining('최근 세션 결과'), findsNothing);
  });

  testWidgets('세션 데이터가 전혀 없을 때도 중복 최근 결과 카드는 만들지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const LiveCenterScreen()),
    );

    expect(find.textContaining('최근 세션 결과'), findsNothing);
  });
}
