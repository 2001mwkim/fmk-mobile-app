import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standing_profiles.dart';
import 'package:fmk_app/models/licensed_image.dart';
import 'package:fmk_app/screens/driver_detail_screen.dart';
import 'package:fmk_app/screens/standings_screen.dart';
import 'package:fmk_app/screens/team_detail_screen.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/licensed_image_view.dart';

void main() {
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
        home: StandingsScreen(repository: _OfflineStandingsRepository()),
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
}

class _OfflineStandingsRepository implements StandingsRepository {
  @override
  Future<StandingsSnapshot?> fetchLatest() async => null;
}
