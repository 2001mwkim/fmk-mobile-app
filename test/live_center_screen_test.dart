import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/screens/live_center_screen.dart';
import 'package:fmk_app/theme/app_colors.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  testWidgets('weather metrics form a readable two-by-two grid on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-08-23T01:00:00Z',
      raceName: 'Dutch Grand Prix',
      sessionType: 'Race',
      sessionName: 'Race',
      weather: LiveWeather(
        airTemperature: 22.4,
        trackTemperature: 31.8,
        humidity: 66,
        windSpeed: 2.7,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );

    final air = tester.getRect(
      find.byKey(const ValueKey('weather-metric-대기 온도')),
    );
    final track = tester.getRect(
      find.byKey(const ValueKey('weather-metric-트랙 온도')),
    );
    final humidity = tester.getRect(
      find.byKey(const ValueKey('weather-metric-습도')),
    );
    final wind = tester.getRect(
      find.byKey(const ValueKey('weather-metric-바람')),
    );

    expect(air.top, track.top);
    expect(humidity.top, wind.top);
    expect(humidity.top, greaterThan(air.bottom));
    expect(air.left, humidity.left);
    expect(track.left, wind.left);
    expect(find.text('22.4°'), findsOneWidget);
    expect(find.text('2.7m/s'), findsOneWidget);
  });

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
          bestSectors: ['28.000'],
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
    // 헤더의 트랙 상태는 이제 색 점(_TrackStatusDot)으로만 표시(텍스트 생략).
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

    // Weather metrics use a stable icon and accent color for quick scanning.
    expect(find.text('대기 온도'), findsOneWidget);
    expect(find.text('트랙 온도'), findsOneWidget);
    expect(find.byIcon(Icons.thermostat_rounded), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.air_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.thermostat_rounded)).color,
      AppColors.weatherAir,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.route_rounded)).color,
      AppColors.weatherTrack,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.water_drop_rounded)).color,
      AppColors.weatherHumidity,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.air_rounded)).color,
      AppColors.weatherWind,
    );

    // SECTOR 탭: S1 라벨 + 값.
    await tester.tap(find.text('SECTOR'));
    await tester.pump();
    expect(find.text('SECTOR TIME'), findsOneWidget);
    expect(find.text('S1 '), findsOneWidget);
    expect(find.text('28.100'), findsOneWidget);
    expect(find.text('28.000'), findsNothing);

    // TIRE 탭: 컴파운드 배지 + 장착 랩 + PIT 횟수.
    await tester.tap(find.text('TIRE'));
    await tester.pump();
    expect(find.text('M'), findsOneWidget);
    expect(find.text('11LAP'), findsOneWidget);
    expect(find.text('1PIT'), findsOneWidget);

    // 'LAP' 텍스트는 헤더 랩 메트릭에도 있어 탭 라벨(뒤쪽)을 지정한다.
    await tester.tap(find.text('LAP').last);
    await tester.pump();
    // 레이스 컨트롤 박스가 자체 스크롤을 가져 화면에 Scrollable이 여러 개다.
    // 바깥(메인 리스트)을 명시해 스크롤한다.
    await tester.scrollUntilVisible(
      find.text('YELLOW FLAG IN TURN 3'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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
      qualifyingPart: 2,
      remainingTime: '12:34',
      classification: [
        LiveDriverPosition(
          position: 1,
          code: 'NOR',
          displayName: '랜도 노리스',
          displayTime: '1:28.100',
          lastLapTime: '1:28.400',
          interval: '+0.100',
        ),
        LiveDriverPosition(
          position: 16,
          code: 'ALB',
          displayName: '알렉산더 알본',
          displayTime: '1:30.100',
          inPit: true,
          qualifyingEliminatedIn: 1,
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
    expect(find.text('Q2'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);
    expect(find.text('PIT'), findsNothing);
  });

  testWidgets('sprint qualifying uses SQ labels for eliminated drivers', (
    tester,
  ) async {
    const snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-07-12T01:00:00Z',
      sessionType: 'Sprint Qualifying',
      sessionName: 'Sprint Qualifying',
      qualifyingPart: 3,
      remainingTime: '07:21',
      classification: [
        LiveDriverPosition(
          position: 11,
          code: 'HUL',
          displayName: '니코 휠켄베르크',
          inPit: true,
          qualifyingEliminatedIn: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );

    expect(find.text('SQ2'), findsOneWidget);
    expect(find.text('SQ3'), findsOneWidget);
    expect(find.text('07:21'), findsOneWidget);
    expect(find.text('PIT'), findsNothing);
  });

  testWidgets('tire timelines share one lap scale and show every driver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-08-21T10:40:00Z',
      raceName: 'Dutch Grand Prix',
      sessionType: 'Practice',
      sessionName: 'Practice 1',
      classification: [
        LiveDriverPosition(
          position: 1,
          code: 'ANT',
          displayName: 'Kimi Antonelli',
          compound: 'MEDIUM',
          tyreAge: 3,
          pitStops: 1,
          stints: [
            LiveStint(compound: 'SOFT', laps: 2),
            LiveStint(compound: 'MEDIUM', laps: 3),
          ],
        ),
        LiveDriverPosition(
          position: 2,
          code: 'NOR',
          displayName: 'Lando Norris',
          compound: 'MEDIUM',
          tyreAge: 5,
          pitStops: 1,
          stints: [
            LiveStint(compound: 'SOFT', laps: 5),
            LiveStint(compound: 'MEDIUM', laps: 5),
          ],
        ),
        LiveDriverPosition(
          position: 3,
          code: 'RUS',
          displayName: 'George Russell',
          compound: 'HARD',
          tyreAge: 4,
          pitStops: 0,
          stints: [LiveStint(compound: 'HARD', laps: 4)],
        ),
        LiveDriverPosition(
          position: 4,
          code: 'HAM',
          displayName: 'Lewis Hamilton',
          compound: 'SOFT',
          tyreAge: 6,
          pitStops: 0,
          stints: [LiveStint(compound: 'SOFT', laps: 6)],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LiveCenterScreen(snapshotOverride: snapshot),
      ),
    );
    await tester.tap(find.text('TIRE'));
    await tester.pump();

    expect(find.text('HAM'), findsOneWidget);
    expect(find.text('4위 이하 순위 보기'), findsNothing);
    expect(find.text('3LAP'), findsOneWidget);
    expect(find.text('1PIT'), findsNWidgets(2));

    final shortBar = tester.getRect(
      find.byKey(const ValueKey('tire-stint-ANT-1')),
    );
    final longestBar = tester.getRect(
      find.byKey(const ValueKey('tire-stint-NOR-1')),
    );
    expect(shortBar.right, lessThan(longestBar.right));
  });

  testWidgets(
    'lap colors distinguish overall, personal best, and slower laps',
    (tester) async {
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
            displayName: 'Lando Norris',
            displayTime: '1:28.100',
            lastLapTime: '1:28.100',
          ),
          LiveDriverPosition(
            position: 2,
            code: 'VER',
            displayName: 'Max Verstappen',
            displayTime: '1:28.500',
            lastLapTime: '1:28.700',
          ),
          LiveDriverPosition(
            position: 3,
            code: 'HAM',
            displayName: 'Lewis Hamilton',
            displayTime: '1:29.000',
            lastLapTime: '1:29.000',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const LiveCenterScreen(snapshotOverride: snapshot),
        ),
      );

      final overallTexts = tester
          .widgetList<Text>(find.text('1:28.100'))
          .toList();
      expect(
        overallTexts.every(
          (text) => text.style?.color == AppColors.timingPurple,
        ),
        isTrue,
      );
      expect(
        tester.widget<Text>(find.text('1:28.500')).style?.color,
        AppColors.slate300,
      );
      expect(
        tester.widget<Text>(find.text('1:28.700')).style?.color,
        AppColors.flagYellow,
      );
      expect(
        tester
            .widgetList<Text>(find.text('1:29.000'))
            .any((text) => text.style?.color == AppColors.greenSoft),
        isTrue,
      );
    },
  );

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
    expect(find.text('+ 3 DRIVERS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4위 이하 순위 보기'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('4위 이하 순위 보기'));
    await tester.pump();
    expect(find.text('D4'), findsOneWidget);
    expect(find.text('D6'), findsOneWidget);

    // 레이스 컨트롤: 접기/펴기 없이 전체를 스크롤 영역에 담는다 → 메시지가
    // 많아도 모두 위젯 트리에 존재(스크롤로 확인). MSG 1~5 모두 렌더된다.
    expect(find.text('MSG 1'), findsOneWidget);
    expect(find.text('MSG 3'), findsOneWidget);
    expect(find.text('MSG 5'), findsOneWidget);
    // 접기/펴기 토글은 제거됨.
    expect(find.text('이전 메시지 보기'), findsNothing);
  });
}
