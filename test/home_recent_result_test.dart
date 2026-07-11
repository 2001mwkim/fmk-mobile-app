import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/race_result.dart';
import 'package:fmk_app/screens/home_screen.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  RaceResultEntry entry(int position, String driverKo, String teamKo) =>
      RaceResultEntry(
        position: position,
        positionLabel: '$position',
        driverKo: driverKo,
        driverEn: 'Driver $position',
        teamKo: teamKo,
        teamEn: 'Team',
        points: 26 - position,
        time: position == 1 ? '1:23:45.678' : null,
        gap: position == 1 ? null : '+$position.0',
      );

  LatestRaceResult latest({String status = 'official'}) => LatestRaceResult(
    raceId: 'australia-2026',
    data: RaceResultData(
      status: status,
      entries: [
        entry(1, '샤를 르클레르', '페라리'),
        entry(2, '조지 러셀', '메르세데스'),
        entry(3, '랜도 노리스', '맥라렌'),
        for (var i = 4; i <= 12; i++) entry(i, '드라이버$i', '팀$i'),
      ],
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

  testWidgets('최근 결과가 있으면 홈에 Top 3 요약 카드가 표시된다', (tester) async {
    await pumpHome(tester, _FakeRepo(latest()));

    await tester.scrollUntilVisible(find.text('최근 레이스 결과'), 200);
    expect(find.text('최근 레이스 결과'), findsOneWidget);
    // 서브타이틀: "그랑프리명 · 결과 상태" 한 줄(디자인 핸드오프)
    expect(find.text('호주 그랑프리 · 공식 결과'), findsOneWidget);
    // Top 3 드라이버/팀 — 4위 이하는 홈 카드에 없다
    expect(find.text('샤를 르클레르'), findsOneWidget);
    expect(find.text('조지 러셀'), findsOneWidget);
    expect(find.text('랜도 노리스'), findsOneWidget);
    expect(find.text('페라리'), findsOneWidget);
    expect(find.text('드라이버4'), findsNothing);
    // 하단 '전체 보기' 버튼은 디자인에서 제거 — 우상단 chevron 이 대체
    expect(find.text('전체 보기'), findsNothing);
    expect(find.byKey(const Key('recent-result-chevron')), findsOneWidget);
  });

  testWidgets('잠정 결과 status 는 잠정 결과로 표시된다', (tester) async {
    await pumpHome(tester, _FakeRepo(latest(status: 'provisional')));

    await tester.scrollUntilVisible(find.text('최근 레이스 결과'), 200);
    expect(find.text('호주 그랑프리 · 잠정 결과'), findsOneWidget);
    expect(find.textContaining('공식 결과'), findsNothing);
  });

  testWidgets('결과가 없으면(null) 홈에 카드가 표시되지 않는다', (tester) async {
    await pumpHome(tester, _FakeRepo(null));

    expect(find.text('최근 레이스 결과'), findsNothing);
    expect(find.byKey(const Key('recent-result-chevron')), findsNothing);
  });

  testWidgets('우상단 chevron 을 누르면 해당 GP 상세 화면으로 이동한다', (tester) async {
    await pumpHome(tester, _FakeRepo(latest()));

    final chevron = find.byKey(const Key('recent-result-chevron'));
    await tester.scrollUntilVisible(chevron, 200);
    // 카드가 리스트 맨 아래라 일부만 노출될 수 있어 완전히 스크롤해 탭한다.
    await tester.ensureVisible(chevron);
    await tester.pumpAndSettle();
    await tester.tap(chevron);
    await tester.pumpAndSettle();

    expect(find.byType(RaceDetailScreen), findsOneWidget);
    expect(find.textContaining('그랑프리 상세'), findsOneWidget);
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
