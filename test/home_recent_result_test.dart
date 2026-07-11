import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/race_result.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  RaceResultEntry entry(int position) => RaceResultEntry(
    position: position,
    positionLabel: '$position',
    driverKo: '드라이버$position',
    driverEn: 'Driver $position',
    teamKo: '팀$position',
    teamEn: 'Team $position',
    points: 0,
    time: position == 1 ? '1:23.456' : null,
    gap: position == 1 ? null : '+$position.0',
  );

  LatestRaceResult latest({String sessionType = 'RACE'}) => LatestRaceResult(
    raceId: 'australia-2026',
    sessionType: sessionType,
    data: RaceResultData(
      status: 'official',
      entries: [for (var i = 1; i <= 12; i++) entry(i)],
    ),
  );

  Future<void> pumpHome(
    WidgetTester tester,
    RaceResultsRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: HomeScreen(resultsRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('홈은 상세 화면과 같은 결과 패널을 최근 세션 제목으로 표시한다', (tester) async {
    await pumpHome(tester, _FakeRepo(latest(sessionType: 'FP1')));

    final title = find.text('최근 세션 결과 (호주 그랑프리 FP1)');
    await tester.scrollUntilVisible(title, 200);
    expect(title, findsOneWidget);
    expect(find.text('드라이버1'), findsOneWidget);
    expect(find.text('공식 결과'), findsNothing);
    expect(find.text('12 DRIVERS'), findsNothing);
  });

  testWidgets('세션 결과가 없으면 홈에 결과 패널을 표시하지 않는다', (tester) async {
    await pumpHome(tester, _FakeRepo(null));
    expect(find.textContaining('최근 세션 결과'), findsNothing);
  });

  testWidgets('홈 결과 패널을 누르면 해당 GP 상세 화면으로 이동한다', (tester) async {
    await pumpHome(tester, _FakeRepo(latest()));

    final title = find.text('최근 세션 결과 (호주 그랑프리 레이스)');
    await tester.scrollUntilVisible(title, 200);
    await tester.tap(title);
    await tester.pumpAndSettle();

    expect(find.byType(RaceDetailScreen), findsOneWidget);
  });
}

class _FakeRepo implements RaceResultsRepository {
  _FakeRepo(this.latestResult);

  final LatestRaceResult? latestResult;

  @override
  Future<RaceResultData?> fetchResult({
    required String raceId,
    int season = 2026,
  }) async => null;

  @override
  Future<LatestRaceResult?> fetchLatest({int season = 2026}) async =>
      latestResult;
}
