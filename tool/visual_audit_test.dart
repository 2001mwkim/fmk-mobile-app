import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/live_session_mock.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/data/standings.dart';
import 'package:fmk_app/screens/calendar_screen.dart';
import 'package:fmk_app/screens/driver_detail_screen.dart';
import 'package:fmk_app/screens/team_detail_screen.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/screens/live_center_screen.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/screens/standings_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('핵심 화면 시각 감사 PNG 생성', (tester) async {
    // 홈의 MY PICKS·알림 카드 등이 prefs 를 읽는다 — 목 없이는 플러그인 예외로 실패.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
      // 홈은 아래 섹션(순위·바로가기)까지 한 장에 보이게 길게 찍는다.
      height: 1240,
      child: HomeScreen(nowOverride: DateTime(2026, 7, 14, 12)),
    );
    // 국기 가운데가 흰색이라 앰비언트 배경 위 가독성이 가장 불리한 GP.
    await _capture(
      tester,
      output: output,
      name: 'home_mexico_390',
      width: 390,
      child: HomeScreen(nowOverride: DateTime(2026, 10, 30, 22)),
    );
    // 라이브/세션 직후에만 뜨는 Top 3 카드까지 포함한 홈.
    await _capture(
      tester,
      output: output,
      name: 'home_live_390',
      width: 390,
      height: 1400,
      child: HomeScreen(
        nowOverride: DateTime(2026, 7, 14, 12),
        liveSnapshotOverride: mockLiveSession,
      ),
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
      name: 'driver_detail_390',
      width: 390,
      height: 2000,
      child: DriverDetailScreen(
        standing: driverStandings.first,
        allDrivers: driverStandings,
        resultsRepository: _FileRaceResultsRepository(),
      ),
    );
    await _capture(
      tester,
      output: output,
      name: 'team_detail_390',
      width: 390,
      height: 2000,
      child: TeamDetailScreen(
        standing: constructorStandings.first,
        allDrivers: driverStandings,
        resultsRepository: _FileRaceResultsRepository(),
      ),
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
  // 굵기별 파일을 모두 등록해야 실기기처럼 w600/w700 이 합성 볼드가 아닌
  // 실제 글리프로 렌더된다(Regular 하나만 넣으면 위계 판단이 왜곡된다).
  final pretendard = FontLoader('Pretendard');
  for (final weight in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ]) {
    pretendard.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.otf'));
  }
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
  double height = 844,
}) async {
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
  // 진입 애니메이션(순위 막대 등)이 끝난 모습을 찍는다.
  await tester.pump(const Duration(seconds: 1));

  await expectLater(find.byKey(key), matchesGoldenFile('../$output/$name.png'));
}

/// 상세 화면 캡처용: build/ui-redesign/race-results.json(collector
/// /race-results.json 저장본)이 있으면 실데이터로, 없으면 정적 폴백으로 그린다.
class _FileRaceResultsRepository extends HttpRaceResultsRepository {
  @override
  Future<SeasonRaceResults?> fetchSeasonResults({int season = 2026}) async {
    final file = File('build/ui-redesign/race-results.json');
    if (!file.existsSync()) return null;
    return parseSeasonRaceResultsJson(file.readAsStringSync());
  }
}
