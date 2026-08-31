import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/gp_guides.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/race.dart';
import 'package:fmk_app/screens/race_detail_screen.dart';
import 'package:fmk_app/theme/app_theme.dart';

Race _race(String id) => races.firstWhere((r) => r.id == id);

Future<void> _pumpDetail(WidgetTester tester, Race race) async {
  // 상세 페이지 카드 전부가 빌드되도록 세로로 긴 화면을 쓴다(ListView lazy).
  tester.view.physicalSize = const Size(800, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: RaceDetailScreen(race: race)),
  );
  await tester.pump();
}

void main() {
  group('gp_guides 데이터 정합성', () {
    test('모든 그랑프리에 가이드가 있다', () {
      for (final race in races) {
        expect(
          gpGuideByRaceId.containsKey(race.id),
          isTrue,
          reason: '${race.id} 의 관전 가이드가 없다',
        );
      }
      // 반대로 달력에 없는 raceId 가 가이드에 남아 있지 않아야 한다.
      final raceIds = races.map((r) => r.id).toSet();
      for (final id in gpGuideByRaceId.keys) {
        expect(raceIds.contains(id), isTrue, reason: '$id 는 달력에 없는 가이드 키');
      }
    });

    test('traits 는 1~5, 타이어는 C1~C5, 우승자는 최신 연도 먼저', () {
      final compound = RegExp(r'^C[1-5]$');
      gpGuideByRaceId.forEach((id, guide) {
        final traits = guide.traits;
        if (traits != null) {
          for (final level in [
            traits.downforce,
            traits.tyreStress,
            traits.overtaking,
          ]) {
            expect(level, inInclusiveRange(1, 5), reason: '$id traits');
          }
        }
        final tyres = guide.tyres;
        if (tyres != null) {
          for (final c in [tyres.hard, tyres.medium, tyres.soft]) {
            expect(compound.hasMatch(c), isTrue, reason: '$id tyre $c');
          }
        }
        for (var i = 1; i < guide.recentWinners.length; i++) {
          expect(
            guide.recentWinners[i].year,
            lessThan(guide.recentWinners[i - 1].year),
            reason: '$id 우승자 정렬',
          );
        }
      });
    });

    test('취소 그랑프리에는 타이어 할당이 없다', () {
      for (final race in races.where((r) => r.isCancelled)) {
        expect(gpGuideByRaceId[race.id]?.tyres, isNull, reason: race.id);
      }
    });
  });

  group('관전 가이드 카드', () {
    testWidgets('타이어·특성·관전 포인트·우승자·랩 레코드가 렌더된다', (tester) async {
      await _pumpDetail(tester, _race('italy-2026'));

      expect(find.text('관전 가이드'), findsOneWidget);
      expect(find.text('타이어 컴파운드'), findsOneWidget);
      expect(find.text('소프트'), findsOneWidget);
      expect(find.text('C5'), findsOneWidget);
      expect(find.text('서킷 특성'), findsOneWidget);
      expect(find.text('추월 난이도'), findsOneWidget);
      expect(find.text('관전 포인트'), findsOneWidget);
      expect(find.text('최근 우승자'), findsOneWidget);
      expect(find.text('샤를 르클레르'), findsOneWidget); // 2024 몬자 우승
      // 서킷 정보 카드의 랩 레코드(2025 노리스).
      expect(find.text('랩 레코드'), findsOneWidget);
      expect(find.text('1:20.901'), findsOneWidget);
    });

    testWidgets('타이어 미발표 라운드는 발표 예정 문구를 보여준다', (tester) async {
      await _pumpDetail(tester, _race('united-states-2026'));

      expect(find.text('피렐리 발표 예정'), findsOneWidget);
      expect(find.text('소프트'), findsNothing);
    });

    testWidgets('취소 그랑프리는 타이어 섹션 없이 가이드만 보여준다', (tester) async {
      await _pumpDetail(tester, _race('saudi-arabia'));

      expect(find.text('관전 가이드'), findsOneWidget);
      expect(find.text('타이어 컴파운드'), findsNothing);
      expect(find.text('피렐리 발표 예정'), findsNothing);
      expect(find.text('최근 우승자'), findsOneWidget);
    });

    testWidgets('신규 서킷(마드리드)은 우승자·랩 레코드 없이 렌더된다', (tester) async {
      await _pumpDetail(tester, _race('spain-2026'));

      expect(find.text('관전 가이드'), findsOneWidget);
      expect(find.text('최근 우승자'), findsNothing);
      expect(find.text('랩 레코드'), findsNothing);
    });
  });
}
