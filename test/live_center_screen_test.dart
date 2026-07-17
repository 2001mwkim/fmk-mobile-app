import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/live_center_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  testWidgets('live center renders timing, weather and race control', (
    tester,
  ) async {
    const snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-07-12T01:00:00Z',
      raceName: 'British Grand Prix',
      sessionType: 'Race',
      sessionName: 'Race',
      currentLap: 21,
      totalLaps: 52,
      trackStatus: '2',
      weather: LiveWeather(
        airTemperature: 22.4,
        trackTemperature: 31.8,
        humidity: 66,
      ),
      classification: [
        LiveDriverPosition(
          position: 1,
          code: 'NOR',
          displayName: '랜도 노리스',
          compound: 'MEDIUM',
          tyreAge: 11,
          pitStops: 1,
          interval: '+0.000',
          sector1: '28.100',
        ),
      ],
      raceControlMessages: [
        LiveRaceControlMessage(
          message: 'YELLOW FLAG IN TURN 3',
          category: 'Flag',
          flag: 'YELLOW',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );

    expect(find.text('라이브 센터'), findsOneWidget);
    expect(find.text('21 / 52'), findsOneWidget);
    expect(find.text('YELLOW'), findsOneWidget);
    expect(find.text('실시간 순위'), findsOneWidget);
    // 라벨링된 상세 줄: 타이어 배지(M) + 랩 수, PIT 횟수, 섹터 라벨.
    expect(find.text('M'), findsOneWidget); // 컴파운드 배지
    expect(find.text('11랩'), findsOneWidget);
    expect(find.text('PIT 1'), findsOneWidget);
    expect(find.textContaining('S1 28.100'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('YELLOW FLAG IN TURN 3'), 200);
    expect(find.text('YELLOW FLAG IN TURN 3'), findsOneWidget);
  });
}
