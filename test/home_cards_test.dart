import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/standing.dart';
import 'package:fmk_app/screens/settings_screen.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';
import 'package:fmk_app/widgets/home_quick_actions_card.dart';
import 'package:fmk_app/widgets/home_standings_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomeStandingsCard', () {
    testWidgets('서버 순위로 TOP 3와 변동(▲/▼)을 표시한다', (tester) async {
      await pump(
        tester,
        HomeStandingsCard(
          repository: _FakeStandingsRepo(
            StandingsSnapshot(
              driverStandings: const [
                DriverStanding(
                  position: 1,
                  driverKo: '드라이버A',
                  driverEn: 'A',
                  teamKo: '메르세데스',
                  teamEn: 'Mercedes',
                  points: 200,
                  positionChange: 0,
                ),
                DriverStanding(
                  position: 2,
                  driverKo: '드라이버B',
                  driverEn: 'B',
                  teamKo: '페라리',
                  teamEn: 'Ferrari',
                  points: 180.5,
                  positionChange: 2,
                ),
                DriverStanding(
                  position: 3,
                  driverKo: '드라이버C',
                  driverEn: 'C',
                  teamKo: '맥라렌',
                  teamEn: 'McLaren',
                  points: 150,
                  positionChange: -1,
                ),
                DriverStanding(
                  position: 4,
                  driverKo: '표시 안 됨',
                  driverEn: 'D',
                  teamKo: '윌리엄스',
                  teamEn: 'Williams',
                  points: 90,
                ),
              ],
              constructorStandings: const [],
            ),
          ),
        ),
      );

      expect(find.text('챔피언십 TOP 3'), findsOneWidget);
      expect(find.text('드라이버A'), findsOneWidget);
      expect(find.text('드라이버B'), findsOneWidget);
      expect(find.text('드라이버C'), findsOneWidget);
      expect(find.text('표시 안 됨'), findsNothing);
      expect(find.text('▲2'), findsOneWidget);
      expect(find.text('▼1'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('180.5'), findsOneWidget);
    });

    testWidgets('서버 실패 시 번들 정적 순위를 그대로 보여준다', (tester) async {
      await pump(
        tester,
        HomeStandingsCard(repository: _FakeStandingsRepo(null)),
      );

      expect(find.text('챔피언십 TOP 3'), findsOneWidget);
      // 정적 데이터 선두(순위 탭과 같은 출처).
      expect(find.text('키미 안토넬리'), findsOneWidget);
    });

    testWidgets('카드를 탭하면 순위 탭 콜백이 호출된다', (tester) async {
      var opened = false;
      await pump(
        tester,
        HomeStandingsCard(
          repository: _FakeStandingsRepo(null),
          onOpenStandings: () => opened = true,
        ),
      );

      await tester.tap(find.text('챔피언십 TOP 3'));
      expect(opened, isTrue);
    });
  });

  group('HomeQuickActionsCard', () {
    testWidgets('알림 설정을 탭하면 설정 화면으로 이동한다', (tester) async {
      await pump(tester, const HomeQuickActionsCard());

      expect(find.text('위젯 추가'), findsOneWidget);
      await tester.tap(find.text('알림 설정'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('위젯 추가를 누르면 두 위젯 중 선택하는 시트가 뜬다', (tester) async {
      String? requested;
      await pump(
        tester,
        HomeQuickActionsCard(
          pinRequester: (name) async {
            requested = name;
            return true;
          },
        ),
      );

      await tester.tap(find.text('위젯 추가'));
      await tester.pumpAndSettle();

      expect(find.text('추가할 위젯 선택'), findsOneWidget);
      expect(find.text('일정 · 라이브 위젯'), findsOneWidget);
      expect(find.text('챔피언십 순위 위젯'), findsOneWidget);

      await tester.tap(find.text('챔피언십 순위 위젯'));
      await tester.pumpAndSettle();

      expect(requested, fmkStandingsWidgetProviderQualifiedName);
      expect(find.byType(SnackBar), findsNothing); // 성공 → 안내 불필요
    });

    testWidgets('pin 미지원이면 수동 추가 안내 스낵바를 띄운다', (tester) async {
      await pump(
        tester,
        HomeQuickActionsCard(pinRequester: (_) async => false),
      );

      await tester.tap(find.text('위젯 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일정 · 라이브 위젯'));
      await tester.pumpAndSettle();

      expect(find.textContaining('홈 화면을 길게 눌러'), findsOneWidget);
    });
  });
}

class _FakeStandingsRepo implements StandingsRepository {
  _FakeStandingsRepo(this.snapshot);

  final StandingsSnapshot? snapshot;

  @override
  Future<StandingsSnapshot?> fetchLatest() async => snapshot;
}
