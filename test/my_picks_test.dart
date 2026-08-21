import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standings.dart' as static_standings;
import 'package:fmk_app/models/standing.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/my_picks_controller.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:fmk_app/widgets/my_picks_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 순위 주입용 — 네트워크 없이 고정 스냅샷을 돌려준다.
class _FakeStandingsRepository implements StandingsRepository {
  const _FakeStandingsRepository(this.snapshot);
  final StandingsSnapshot? snapshot;
  @override
  Future<StandingsSnapshot?> fetchLatest() async => snapshot;
}

void main() {
  group('MyPicksController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('비어 있으면 둘 다 null, 저장 후 로드하면 코드/팀이 유지된다', () async {
      final controller = MyPicksController();
      expect((await controller.load()).hasDriver, isFalse);

      await controller.saveDriver('lec');
      await controller.saveTeam('페라리');
      expect(controller.picks.driverCode, 'LEC'); // 대문자 정규화
      expect(controller.picks.teamKo, '페라리');

      final reloaded = MyPicksController();
      final picks = await reloaded.load();
      expect(picks.driverCode, 'LEC');
      expect(picks.teamKo, '페라리');
    });

    test('null/빈 값 저장은 해제이고, 드라이버와 팀은 서로 독립이다', () async {
      final controller = MyPicksController();
      await controller.saveDriver('HAM');
      await controller.saveTeam('맥라렌');
      await controller.saveDriver(null);
      expect(controller.picks.hasDriver, isFalse);
      expect(controller.picks.teamKo, '맥라렌');
      await controller.saveTeam('');
      expect(controller.picks, MyPicks.empty);
    });
  });

  group('buildFmkMyPicksPayload', () {
    const drivers = [
      DriverStanding(
        position: 1,
        driverKo: '키미 안토넬리',
        driverEn: 'Kimi Antonelli',
        teamKo: '메르세데스',
        teamEn: 'Mercedes',
        points: 156,
        positionChange: 0,
      ),
      DriverStanding(
        position: 2,
        driverKo: '루이스 해밀턴',
        driverEn: 'Lewis Hamilton',
        teamKo: '페라리',
        teamEn: 'Ferrari',
        points: 115,
        positionChange: 1,
      ),
      DriverStanding(
        position: 4,
        driverKo: '샤를 르클레르',
        driverEn: 'Charles Leclerc',
        teamKo: '페라리',
        teamEn: 'Ferrari',
        points: 75.5,
        positionChange: -1,
      ),
    ];
    const teams = [
      ConstructorStanding(
        position: 1,
        teamKo: '메르세데스',
        teamEn: 'Mercedes',
        points: 262,
      ),
      ConstructorStanding(
        position: 2,
        teamKo: '페라리',
        teamEn: 'Ferrari',
        points: 190,
        positionChange: 2,
      ),
    ];

    test('미설정이면 둘 다 null', () {
      final payload = buildFmkMyPicksPayload(
        picks: MyPicks.empty,
        driverStandings: drivers,
        constructorStandings: teams,
      );
      expect(payload.driver, isNull);
      expect(payload.team, isNull);
    });

    test('드라이버: 코드 → 영문 이름/팀/순위/포인트/격차/변동', () {
      final d = buildFmkMyPicksPayload(
        picks: const MyPicks(driverCode: 'LEC'),
        driverStandings: drivers,
        constructorStandings: teams,
      ).driver!;
      expect(d.found, isTrue);
      expect(d.code, 'LEC');
      expect(d.nameEn, 'Charles Leclerc');
      expect(d.nameKo, '샤를 르클레르');
      expect(d.teamEn, 'Ferrari');
      expect(d.position, 4);
      expect(d.points, '75.5');
      expect(d.gapToLeader, '-80.5');
      expect(d.changeLabel, '▼1');
      expect(d.teamColor, 0xFFE80020);
    });

    test('선두 드라이버의 격차는 LEADER', () {
      final d = buildFmkMyPicksPayload(
        picks: const MyPicks(driverCode: 'ANT'),
        driverStandings: drivers,
        constructorStandings: teams,
      ).driver!;
      expect(d.position, 1);
      expect(d.gapToLeader, 'LEADER');
      expect(d.changeLabel, '—');
    });

    test('순위에 없는 드라이버는 found=false 지만 이름/팀 컬러는 채운다', () {
      final d = buildFmkMyPicksPayload(
        picks: const MyPicks(driverCode: 'NOR'),
        driverStandings: drivers,
        constructorStandings: teams,
      ).driver!;
      expect(d.found, isFalse);
      expect(d.nameEn, 'Lando Norris');
      expect(d.position, 0);
      expect(d.points, '');
      expect(d.teamColor, 0xFFFF8700); // drivers.dart 액센트(맥라렌)
    });

    test('팀: 약어/영문명/순위/격차 + 소속 드라이버 순위순 2명', () {
      final t = buildFmkMyPicksPayload(
        picks: const MyPicks(teamKo: '페라리'),
        driverStandings: drivers,
        constructorStandings: teams,
      ).team!;
      expect(t.found, isTrue);
      expect(t.code, 'FER');
      expect(t.teamEn, 'Ferrari');
      expect(t.position, 2);
      expect(t.points, '190');
      expect(t.gapToLeader, '-72');
      expect(t.changeLabel, '▲2');
      expect(t.drivers.map((d) => d.code).toList(), ['HAM', 'LEC']);
      expect(t.drivers.first.position, 2);
      expect(t.teamColor, 0xFFE80020);
    });

    test('정적 순위(번들)로도 모든 팀 키가 맞물린다', () {
      for (final c in static_standings.constructorStandings) {
        final t = buildFmkMyPicksPayload(
          picks: MyPicks(teamKo: c.teamKo),
          driverStandings: static_standings.driverStandings,
          constructorStandings: static_standings.constructorStandings,
        ).team!;
        expect(t.found, isTrue, reason: c.teamKo);
        expect(t.code, isNot('—'), reason: c.teamKo);
        expect(t.drivers, isNotEmpty, reason: c.teamKo);
      }
    });
  });

  test('fmkWidgetOpensMyPicks 는 mypicks 호스트만 설정 화면으로 보낸다', () {
    expect(fmkWidgetOpensMyPicks(Uri.parse('fmkwidget://mypicks')), isTrue);
    expect(
      fmkWidgetOpensMyPicks(Uri.parse('fmkwidget://mypicks?homeWidget')),
      isTrue,
    );
    expect(fmkWidgetOpensMyPicks(Uri.parse('fmkwidget://standings')), isFalse);
    expect(fmkWidgetOpensMyPicks(null), isFalse);
    expect(fmkWidgetTabIndexForUri(Uri.parse('fmkwidget://mypicks')), isNull);
  });

  group('MyPicksCard', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<MyPicksController> pump(WidgetTester tester) async {
      final controller = MyPicksController();
      var changed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MyPicksCard(
                controller: controller,
                standingsRepository: const _FakeStandingsRepository(null),
                onChanged: () async => changed++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('빈 상태 타일 → 드라이버 선택기에서 고르면 타일에 반영된다', (
      tester,
    ) async {
      final controller = await pump(tester);
      expect(find.text('드라이버 선택'), findsOneWidget);
      expect(find.text('팀 선택'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-pick-driver')));
      await tester.pumpAndSettle();
      expect(find.text('응원하는 드라이버를 고르세요'), findsOneWidget);
      // 미설정 상태에서는 해제 버튼이 없다.
      expect(find.byKey(const ValueKey('my-pick-clear')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('pick-driver-LEC')));
      await tester.pumpAndSettle();

      expect(controller.picks.driverCode, 'LEC');
      expect(find.text('LEC'), findsOneWidget);
      expect(find.text('Charles Leclerc'), findsOneWidget);
      expect(find.textContaining('MY DRIVER · 샤를 르클레르'), findsOneWidget);
    });

    testWidgets('팀 선택 후 해제하면 빈 상태로 돌아간다', (tester) async {
      final controller = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('my-pick-team')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-team-맥라렌')));
      await tester.pumpAndSettle();
      expect(controller.picks.teamKo, '맥라렌');
      // 타일은 팀 풀네임(대문자) + 소속 드라이버 코드를 보여준다.
      expect(find.text('MCLAREN'), findsOneWidget);
      expect(find.text('NOR · PIA'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-pick-team')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-pick-clear')));
      await tester.pumpAndSettle();
      expect(controller.picks.hasTeam, isFalse);
      expect(find.text('팀 선택'), findsOneWidget);
    });
  });
}
