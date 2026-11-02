import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standings.dart' as static_standings;
import 'package:fmk_app/models/race_result.dart';
import 'package:fmk_app/widgets/share_card.dart';

RaceResultEntry _entry(int position, {String? time, String? gap}) =>
    RaceResultEntry(
      position: position,
      positionLabel: '$position',
      driverKo: '드라이버 $position',
      driverEn: 'Driver $position',
      teamKo: '맥라렌',
      teamEn: 'McLaren',
      points: 0,
      time: time,
      gap: gap,
    );

void main() {
  test('레이스는 1위 총시간 + 갭, 퀄리는 행별 랩타임을 쓴다', () {
    final entries = [
      _entry(1, time: '1:32:10.123', gap: null),
      _entry(2, time: '1:32:15.000', gap: '+4.877'),
    ];
    expect(
      shareRowsFromResults(entries, gapBased: true).map((r) => r.value),
      ['1:32:10.123', '+4.877'],
    );
    expect(
      shareRowsFromResults(entries, gapBased: false).map((r) => r.value),
      ['1:32:10.123', '1:32:15.000'],
    );
  });

  test('순위는 상위 10개만, 포인트는 정수면 소수점 없이', () {
    final rows = shareRowsFromDriverStandings(static_standings.driverStandings);
    expect(rows, hasLength(10));
    expect(rows.first.value, endsWith(' PTS'));
    expect(rows.first.value, isNot(contains('.0 ')));
  });

  testWidgets('카드는 큰 글자 설정에서도 고정 크기로 넘침 없이 그려진다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Center(
            child: ShareCard(
              eyebrow: 'R20 · 2026',
              title: '아주 긴 이름의 멕시코시티 그랑프리 스프린트 퀄리파잉 결과',
              rows: shareRowsFromConstructorStandings(
                static_standings.constructorStandings,
              ),
              note: '잠정 결과',
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ShareCard)), kShareCardSize);
    expect(find.text('비아 포뮬러'), findsOneWidget);
  });

  testWidgets('공유 시트는 미리보기와 공유 버튼을 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showShareCardSheet(
                context,
                fileName: 'test',
                card: ShareCard(
                  eyebrow: 'R1',
                  title: '호주 그랑프리 레이스 결과',
                  rows: shareRowsFromResults([
                    _entry(1, time: '1:30:00.000'),
                  ], gapBased: true),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('이미지로 공유'), findsOneWidget);
    expect(find.text('호주 그랑프리 레이스 결과'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);
  });
}
