import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standing_profiles.dart';
import 'package:fmk_app/data/standing_insights.dart';
import 'package:fmk_app/models/licensed_image.dart';
import 'package:fmk_app/models/race_result.dart';
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

  testWidgets('driver row opens the redesigned detail with photo credits', (
    tester,
  ) async {
    await pumpStandings(tester);

    await tester.tap(find.text('키미 안토넬리'));
    await tester.pumpAndSettle();

    expect(find.byType(DriverDetailScreen), findsOneWidget);
    // 2026-10 재설계: 사진 헤더 → 성적 한 줄 → 라운드별 포인트 → 맞대결 → 시즌 결과.
    expect(find.byType(DetailHero), findsOneWidget);
    expect(find.text('우승'), findsOneWidget);
    expect(find.text('포디움'), findsOneWidget);
    expect(find.byType(SeasonPointsCard), findsOneWidget);
    expect(find.text('라운드별 포인트'), findsNothing);
    expect(find.text('드라이버 상세 · 2026 SEASON'), findsNothing);
    expect(find.text('팀메이트 맞대결'), findsOneWidget);
    expect(find.text('시즌 결과'), findsOneWidget);
    // 사진 상자(LicensedImageView)는 헤더 배경으로 옮겨 더는 쓰지 않는다.
    expect(find.byType(LicensedImageView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('photo-credits-button')));
    await tester.pumpAndSettle();
    expect(find.text('Photo credits'), findsOneWidget);
    expect(find.text('Photo: Yu Chu Chin · CC BY-SA 4.0'), findsOneWidget);
    expect(find.textContaining('Cropped'), findsNothing);
  });

  testWidgets('constructor row opens the redesigned detail and driver links', (
    tester,
  ) async {
    await pumpStandings(tester);

    await tester.tap(find.text('컨스트럭터'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('메르세데스'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamDetailScreen), findsOneWidget);
    expect(find.byType(DetailHero), findsOneWidget);
    expect(find.text('팀 포인트 기여도'), findsOneWidget);
    expect(find.text('컨스트럭터 상세 · 2026 SEASON'), findsNothing);

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

  test('팀메이트 맞대결은 완주가 리타이어보다 앞서고, 둘 다 리타이어면 뺀다', () {
    RaceResultEntry entry(String name, int position, [String? label]) =>
        RaceResultEntry(
          position: position,
          positionLabel: label ?? '$position',
          driverKo: name,
          driverEn: name,
          teamKo: '팀',
          teamEn: 'Team',
          points: 0,
        );
    final h2h = headToHead(
      'A',
      'B',
      resultsByRaceId: {
        'r1': [entry('A', 1), entry('B', 2)],
        'r2': [entry('B', 3), entry('A', 20, 'DNF')],
        'r3': [entry('A', 19, 'DNF'), entry('B', 20, 'DNF')],
        'r4': [entry('B', 5), entry('A', 18, 'DNF')],
        'r5': [entry('A', 4)],
      },
    );
    expect(h2h.wins, 1);
    expect(h2h.losses, 2);
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
