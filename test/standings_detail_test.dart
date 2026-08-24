import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standing_profiles.dart';
import 'package:fmk_app/models/licensed_image.dart';
import 'package:fmk_app/models/standing.dart';
import 'package:fmk_app/screens/driver_detail_screen.dart';
import 'package:fmk_app/screens/standings_screen.dart';
import 'package:fmk_app/screens/team_detail_screen.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/licensed_image_view.dart';
import 'package:fmk_app/widgets/standing_detail_parts.dart';

void main() {
  test('순위 흐름 축 눈금은 중복 없이 실제 정수 좌표를 사용한다', () {
    expect(standingTrendAxisTicks(1, 3), [1, 2, 3]);
    expect(standingTrendAxisTicks(1, 5), [1, 2, 4, 5]);
    expect(standingTrendAxisTicks(1, 12), [1, 5, 8, 12]);
  });

  test('licensed image catalog stays on Commons and tracks file edits', () {
    final images = [
      ...driverProfilesByCode.values.map((profile) => profile.image),
      ...teamProfilesByKo.values.map((profile) => profile.image),
    ].whereType<LicensedImage>();

    expect(images, isNotEmpty);
    expect(
      images.every(
        (image) =>
            Uri.parse(image.imageUrl).host == 'commons.wikimedia.org' &&
            Uri.parse(image.sourceUrl).host == 'commons.wikimedia.org' &&
            image.licenseUrl.startsWith('https://creativecommons.org/'),
      ),
      isTrue,
    );
    // Runtime BoxFit cropping is not a file modification.
    expect(driverProfilesByCode['ANT']!.image!.modified, isFalse);
    // This registered Commons source is itself a cropped derivative.
    expect(driverProfilesByCode['HUL']!.image!.modified, isTrue);
  });

  Future<void> pumpStandings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StandingsScreen(
          repository: _OfflineStandingsRepository(),
          resultsRepository: _OfflineRaceResultsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('driver row opens a 4:5 licensed detail hero and credits', (
    tester,
  ) async {
    await pumpStandings(tester);

    await tester.tap(find.text('키미 안토넬리'));
    await tester.pumpAndSettle();

    expect(find.byType(DriverDetailScreen), findsOneWidget);
    expect(find.text('드라이버 상세 · 2026 SEASON'), findsOneWidget);
    expect(find.text('시즌 성과'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_outlined), findsOneWidget);
    expect(find.text('시즌 순위 흐름'), findsOneWidget);
    expect(find.text('팀메이트 비교'), findsOneWidget);

    final imageView = find.byType(LicensedImageView);
    expect(imageView, findsOneWidget);
    final ratio = tester.widget<AspectRatio>(
      find.descendant(of: imageView, matching: find.byType(AspectRatio)),
    );
    expect(ratio.aspectRatio, 4 / 5);

    await tester.tap(find.byKey(const ValueKey('photo-credits-button')));
    await tester.pumpAndSettle();
    expect(find.text('Photo credits'), findsOneWidget);
    expect(find.text('Photo: Yu Chu Chin · CC BY-SA 4.0'), findsOneWidget);
    expect(find.textContaining('Cropped'), findsNothing);
  });

  testWidgets('constructor row opens a 16:9 car hero and driver links', (
    tester,
  ) async {
    await pumpStandings(tester);

    await tester.tap(find.text('컨스트럭터'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('메르세데스'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamDetailScreen), findsOneWidget);
    expect(find.text('컨스트럭터 상세 · 2026 SEASON'), findsOneWidget);
    expect(find.text('드라이버 포인트 기여도'), findsOneWidget);

    final imageView = find.byType(LicensedImageView);
    final ratio = tester.widget<AspectRatio>(
      find.descendant(of: imageView, matching: find.byType(AspectRatio)),
    );
    expect(ratio.aspectRatio, 16 / 9);

    final kimiLink = find.byKey(const ValueKey('team-driver-키미 안토넬리'));
    await tester.scrollUntilVisible(
      kimiLink,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(kimiLink);
    await tester.pumpAndSettle();
    expect(find.byType(DriverDetailScreen), findsOneWidget);
  });

  testWidgets('레드불 기여도에는 베르스타펜과 하자르만 표시한다', (tester) async {
    const team = ConstructorStanding(
      position: 4,
      teamKo: '레드불 레이싱',
      teamEn: 'Red Bull',
      points: 180,
    );
    const drivers = [
      DriverStanding(
        position: 6,
        driverKo: '막스 베르스타펜',
        driverEn: 'Max Verstappen',
        teamKo: '레드불 레이싱',
        teamEn: 'Red Bull',
        points: 112,
      ),
      DriverStanding(
        position: 8,
        driverKo: '아이작 하자르',
        driverEn: 'Isack Hadjar',
        teamKo: '레드불 레이싱',
        teamEn: 'Red Bull',
        points: 68,
      ),
      DriverStanding(
        position: 9,
        driverKo: '리암 로슨',
        driverEn: 'Liam Lawson',
        teamKo: '레드불 레이싱',
        teamEn: 'Red Bull',
        points: 49,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const TeamDetailScreen(
          standing: team,
          allDrivers: drivers,
          resultsRepository: _OfflineRaceResultsRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('team-driver-막스 베르스타펜')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('막스 베르스타펜'), findsOneWidget);
    expect(find.text('아이작 하자르'), findsOneWidget);
    expect(find.text('리암 로슨'), findsNothing);
  });
}

class _OfflineStandingsRepository implements StandingsRepository {
  @override
  Future<StandingsSnapshot?> fetchLatest() async => null;
}

class _OfflineRaceResultsRepository implements RaceResultsRepository {
  const _OfflineRaceResultsRepository();

  @override
  Future<RaceResultData?> fetchResult({
    required String raceId,
    int season = 2026,
  }) async => null;

  @override
  Future<List<SessionResultData>?> fetchSessionResults({
    required String raceId,
    int season = 2026,
  }) async => null;

  @override
  Future<LatestRaceResult?> fetchLatest({int season = 2026}) async => null;

  @override
  Future<SeasonRaceResults?> fetchSeasonResults({int season = 2026}) async =>
      null;
}
