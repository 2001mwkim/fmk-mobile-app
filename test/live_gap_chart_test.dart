import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/gap_history.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/gap_history_controller.dart';
import 'package:fmk_app/widgets/live_gap_chart.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _body = '''
{"available": true, "raceId": "mexico-2026", "sessionType": "race",
 "generatedAt": "2026-11-01T20:00:00Z", "requestedDelaySeconds": 0,
 "drivers": ["VER", "NOR", "LEC", "HAM", "RUS", "PIA"],
 "laps": [
   {"lap": 2, "gaps": {"VER": 0, "NOR": 1.8, "LEC": 3.1, "HAM": 4.0, "RUS": 5.2, "PIA": 6.0}},
   {"lap": 1, "gaps": {"VER": 0, "NOR": 1.2, "LEC": 2.5, "HAM": null, "RUS": 4.9, "PIA": 5.1}},
   {"lap": 3, "gaps": {"VER": 0, "NOR": 2.4, "LEC": 3.0, "HAM": 4.6, "RUS": 5.0, "PIA": 7.2}}
 ]}
''';

void main() {
  test('응답을 랩 오름차순으로 읽고 null 랩은 시리즈에서 뺀다', () {
    final history = GapHistory.tryParse(_body)!;
    expect(history.hasData, isTrue);
    expect(history.laps.map((l) => l.lap), [1, 2, 3]);
    expect(history.seriesFor('HAM'), [(2, 4.0), (3, 4.6)]);
    expect(history.seriesFor('VER').first, (1, 0.0));
    expect(GapHistory.tryParse('nope'), isNull);
  });

  test('live.json 과 같은 호스트에서만 URL 을 만든다', () {
    expect(
      liveGapHistoryUrlFor('https://live.formulamagazine.kr/live.json'),
      'https://live.formulamagazine.kr/gap-history.json',
    );
    expect(liveGapHistoryUrlFor('https://www.formulamagazine.kr/api/live'), isNull);
  });

  test('세로축 상한은 5초 단위, 5~60초 사이', () {
    expect(gapChartCeiling([0, 2.4]), 5);
    expect(gapChartCeiling([0, 12.1]), 15);
    expect(gapChartCeiling([0, 95]), 60);
    expect(gapChartCeiling(const []), 5);
  });

  test('지연값을 쿼리로 붙여 요청한다', () async {
    Uri? requested;
    final controller = GapHistoryController(
      delaySeconds: 35,
      url: 'https://live.example/gap-history.json',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(_body, 200);
      }),
    );
    await controller.poll();
    expect(requested!.queryParameters['delay'], '35');
    expect(controller.history.drivers, hasLength(6));
    controller.dispose();
  });

  testWidgets('기본으로 상위 5명을 그리고 칩으로 켜고 끈다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = GapHistoryController(
      delaySeconds: 0,
      url: 'https://live.example/gap-history.json',
      client: MockClient((_) async => http.Response(_body, 200)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LiveGapChartCard(
              snapshot: const LiveSessionSnapshot(
                status: LiveSessionStatus.live,
                updatedAt: '2026-11-01T20:00:00Z',
                sessionType: 'Race',
              ),
              delaySeconds: 0,
              controllerFactory: (_) => controller,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => controller.poll());
    await tester.pump();

    expect(find.text('선두와의 간격 · 3랩까지'), findsOneWidget);
    FilterChip chip(String code) =>
        tester.widget<FilterChip>(find.byKey(ValueKey('gap-chip-$code')));
    expect(chip('VER').selected, isTrue);
    expect(chip('RUS').selected, isTrue);
    expect(chip('PIA').selected, isFalse);

    await tester.tap(find.byKey(const ValueKey('gap-chip-PIA')));
    await tester.pump();
    expect(chip('PIA').selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('gap-chip-VER')));
    await tester.pump();
    expect(chip('VER').selected, isFalse);
  });

  test('연습·퀄리에는 카드를 띄우지 않는다', () {
    expect(
      LiveGapChartCard.appliesTo(
        const LiveSessionSnapshot(
          status: LiveSessionStatus.live,
          updatedAt: '',
          sessionType: 'Qualifying',
        ),
      ),
      isFalse,
    );
  });
}
