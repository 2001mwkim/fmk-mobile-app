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

    // 라이브 보드 탭: LAP(기본) / SECTOR / TIRE.
    // ('LAP'은 세션 헤더 랩 메트릭 라벨과 탭 라벨 두 곳에 존재)
    expect(find.text('LAP'), findsWidgets);
    expect(find.text('SECTOR'), findsOneWidget);
    expect(find.text('TIRE'), findsOneWidget);
    // 레이스 LAP 탭: INTERVAL이 우선이며 섹터 시간은 중복 표시하지 않는다.
    expect(find.text('INTERVAL'), findsOneWidget);
    expect(find.text('BEST'), findsWidgets);
    expect(find.text('LAST'), findsOneWidget);
    expect(find.text('28.100'), findsNothing);

    // SECTOR 탭: S1 라벨 + 값.
    await tester.tap(find.text('SECTOR'));
    await tester.pump();
    expect(find.text('SECTOR TIME'), findsOneWidget);
    expect(find.text('S1 '), findsOneWidget);
    expect(find.text('28.100'), findsOneWidget);

    // TIRE 탭: 컴파운드 배지 + 장착 랩 + PIT 횟수.
    await tester.tap(find.text('TIRE'));
    await tester.pump();
    expect(find.text('M'), findsOneWidget);
    expect(find.text('11랩'), findsOneWidget);
    expect(find.text('PIT 1'), findsOneWidget);

    // 'LAP' 텍스트는 헤더 랩 메트릭에도 있어 탭 라벨(뒤쪽)을 지정한다.
    await tester.tap(find.text('LAP').last);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('YELLOW FLAG IN TURN 3'), 200);
    expect(find.text('YELLOW FLAG IN TURN 3'), findsOneWidget);
  });

  testWidgets('time-attack sessions prioritize best lap instead of interval', (
    tester,
  ) async {
    const snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-07-12T01:00:00Z',
      raceName: 'British Grand Prix',
      sessionType: 'Qualifying',
      sessionName: 'Qualifying',
      classification: [
        LiveDriverPosition(
          position: 1,
          code: 'NOR',
          displayName: '랜도 노리스',
          displayTime: '1:28.100',
          lastLapTime: '1:28.400',
          interval: '+0.100',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );

    expect(find.text('BEST LAP'), findsOneWidget);
    expect(find.text('INTERVAL'), findsNothing);
    expect(find.text('1:28.100'), findsOneWidget);
    expect(find.text('1:28.400'), findsOneWidget);
  });

  testWidgets('timing and race control collapse beyond the latest three', (
    tester,
  ) async {
    final snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-07-17T12:00:00Z',
      raceName: 'Belgian Grand Prix',
      sessionType: 'Race',
      sessionName: 'Race',
      classification: [
        for (var i = 1; i <= 6; i++)
          LiveDriverPosition(
            position: i,
            code: 'D$i',
            displayName: '드라이버$i',
            interval: i == 1 ? null : '+$i.0',
          ),
      ],
      raceControlMessages: [
        for (var i = 1; i <= 5; i++) LiveRaceControlMessage(message: 'MSG $i'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );

    // 순위: Top 3 상시 노출, 4위 이하는 접힘 → 펼치면 보인다.
    // (행에서 한글 이름을 뺐으므로 드라이버 식별은 코드로 확인한다.)
    expect(find.text('D3'), findsOneWidget);
    expect(find.text('D4'), findsNothing);
    await tester.scrollUntilVisible(find.text('4위 이하 순위 보기'), 200);
    await tester.tap(find.text('4위 이하 순위 보기'));
    await tester.pump();
    expect(find.text('D4'), findsOneWidget);
    expect(find.text('D6'), findsOneWidget);

    // 레이스 컨트롤: 최신 3개 상시, 이전은 접힘 → 펼치면 보인다.
    expect(find.text('MSG 3'), findsOneWidget);
    expect(find.text('MSG 4'), findsNothing);
    await tester.scrollUntilVisible(find.text('이전 메시지 보기'), 200);
    // 리스트 하단 경계에 걸리면 탭이 빗나가므로 완전히 화면 안으로 끌어온다.
    await tester.ensureVisible(find.text('이전 메시지 보기'));
    await tester.pump();
    await tester.tap(find.text('이전 메시지 보기'));
    await tester.pump();
    expect(find.text('MSG 4'), findsOneWidget);
    expect(find.text('MSG 5'), findsOneWidget);
  });
}
