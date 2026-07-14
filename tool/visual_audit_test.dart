import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/live_session_mock.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/screens/calendar_screen.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/screens/live_center_screen.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/screens/standings_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('핵심 화면 시각 감사 PNG 생성', (tester) async {
    await tester.runAsync(_loadAuditFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final output =
        Platform.environment['UI_AUDIT_OUTPUT'] ?? 'docs/ui-audit/after';
    final longestRace = races.reduce(
      (a, b) => a.nameKo.length >= b.nameKo.length ? a : b,
    );
    final longRaceStart = DateTime.parse(longestRace.startDate);

    await _capture(
      tester,
      output: output,
      name: 'home_360_text130',
      width: 360,
      textScale: 1.3,
      child: HomeScreen(
        nowOverride: longRaceStart.subtract(const Duration(days: 3)),
      ),
    );
    await _capture(
      tester,
      output: output,
      name: 'home_390',
      width: 390,
      child: HomeScreen(nowOverride: DateTime(2026, 7, 14, 12)),
    );
    await _capture(
      tester,
      output: output,
      name: 'calendar_390',
      width: 390,
      child: const CalendarScreen(),
    );
    await _capture(
      tester,
      output: output,
      name: 'calendar_430_text130',
      width: 430,
      textScale: 1.3,
      child: const CalendarScreen(),
    );
    await _capture(
      tester,
      output: output,
      name: 'gp_detail_390',
      width: 390,
      child: RaceDetailScreen(race: longestRace),
    );
    await _capture(
      tester,
      output: output,
      name: 'standings_390',
      width: 390,
      child: const StandingsScreen(),
    );
    await _capture(
      tester,
      output: output,
      name: 'live_390',
      width: 390,
      child: LiveCenterScreen(snapshotOverride: mockLiveSession),
    );
    await _capture(
      tester,
      output: output,
      name: 'live_empty_390',
      width: 390,
      child: const LiveCenterScreen(snapshotOverride: null),
    );
  });
}

Future<void> _loadAuditFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/2001m/flutter';
  final pretendard = FontLoader('Pretendard')
    ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(
      File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  await Future.wait([pretendard.load(), materialIcons.load()]);
}

Future<void> _capture(
  WidgetTester tester, {
  required String output,
  required String name,
  required double width,
  required Widget child,
  double textScale = 1,
}) async {
  const height = 844.0;
  final key = GlobalKey();
  tester.view.physicalSize = Size(width, height);

  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: child,
        ),
      ),
    ),
  );
  // 네트워크/컨트롤러의 첫 비동기 갱신이 같은 프레임에 겹치지 않게 한 뒤 캡처한다.
  await tester.pump(const Duration(milliseconds: 100));

  await expectLater(find.byKey(key), matchesGoldenFile('../$output/$name.png'));
}
