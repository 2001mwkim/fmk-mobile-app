import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/track_outlines.dart';
import 'package:fmk_app/models/live_positions.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/live_positions_controller.dart';
import 'package:fmk_app/services/live_session_service.dart';
import 'package:fmk_app/widgets/live_team_radio_card.dart';
import 'package:fmk_app/widgets/live_track_map.dart';

/// collector `/positions.json` 형식(2Hz·13프레임)을 흉내 낸 본문.
String _body({int t0 = 1000000, int count = 13, double startX = 0}) {
  final xs = [for (var i = 0; i < count; i++) '${startX + i * 100},50'];
  return '{"v":1,"available":true,"t0":$t0,"dt":500,"count":$count,'
      '"cars":{"1":[${xs.join(',')}],"44":[${List.filled(count, 'null,null').join(',')}]}}';
}

void main() {
  group('LivePositionsWindow / Timeline', () {
    test('parses the collector payload and rejects unavailable bodies', () {
      final w = LivePositionsWindow.tryParse(_body())!;
      expect(w.count, 13);
      expect(w.endMs, 1000000 + 12 * 500);
      expect(w.cars['1']!.take(4), [0, 50, 100, 50]);
      expect(LivePositionsWindow.tryParse('{"v":1,"available":false}'), isNull);
      expect(LivePositionsWindow.tryParse('not json'), isNull);
    });

    test('interpolates between frames and skips cars without a position', () {
      final timeline = LivePositionTimeline()
        ..add(LivePositionsWindow.tryParse(_body())!);
      final mid = timeline.sample(1000000 + 250);
      expect(mid['1'], const Offset(50, 50));
      expect(mid.containsKey('44'), isFalse);
    });

    test('freezes at the ends instead of extrapolating', () {
      final timeline = LivePositionTimeline()
        ..add(LivePositionsWindow.tryParse(_body())!);
      expect(timeline.sample(0)['1'], const Offset(0, 50));
      expect(timeline.sample(99999999)['1'], const Offset(1200, 50));
    });

    test('does not interpolate across a tracking jump (pit entry etc.)', () {
      final timeline = LivePositionTimeline()
        ..add(
          LivePositionsWindow.tryParse(
            '{"v":1,"available":true,"t0":0,"dt":500,"count":2,"cars":{"1":[0,0,9000,0]}}',
          )!,
        );
      expect(timeline.sample(250)['1'], Offset.zero);
    });

    test('later windows overwrite overlapping frames and old ones are pruned', () {
      final timeline = LivePositionTimeline(retention: const Duration(seconds: 10))
        ..add(LivePositionsWindow.tryParse(_body())!)
        ..add(LivePositionsWindow.tryParse(_body(t0: 1000000 + 20000))!);
      expect(timeline.sample(1000000)['1'], const Offset(0, 50));
      expect(timeline.latestMs, 1000000 + 20000 + 6000);
    });
  });

  group('LivePositionsController', () {
    test('derives the positions URL from live.json only', () {
      expect(
        livePositionsUrlFor('https://live.formulamagazine.kr/live.json'),
        'https://live.formulamagazine.kr/positions.json',
      );
      // Vercel 폴백은 좌표를 중계하지 않는다 → 지도 끔.
      expect(livePositionsUrlFor('https://www.formulamagazine.kr/api/live'), isNull);
    });

    test('renders a few seconds behind the freshest window', () {
      final c = LivePositionsController(delaySeconds: 0, url: '');
      final w = LivePositionsWindow.tryParse(_body(t0: 0))!;
      c.timeline.add(w);
      // 서버 최신 프레임(6000ms)을 로컬 10000ms 에 받았다 → 오프셋 −4000.
      c.recordOffset(w.endMs, 10000);
      // 로컬 11000ms → 서버 7000ms − 지연 5000ms = 2000ms → x = 400.
      final now = DateTime.fromMillisecondsSinceEpoch(11000);
      expect(c.positionsAt(now)['1'], const Offset(400, 50));
    });
  });

  group('TrackOutline', () {
    test('uses the same rotation formula as the outline generator', () {
      final outline = TrackOutline(
        rotationDeg: 90,
        rawPoints: [for (var i = 0; i < 20; i++) Offset(i.toDouble(), 0)],
      );
      final p = outline.project(const Offset(1, 0));
      expect(p.dx, closeTo(0, 1e-9));
      expect(p.dy, closeTo(-1, 1e-9));
    });

    testWidgets('bundled asset has every remaining 2026 GP circuit', (tester) async {
      // 실제 에셋 I/O 는 fake async 밖에서 돌려야 끝난다.
      await tester.runAsync(() async {
        for (final id in ['mexico-2026', 'brazil-2026', 'las-vegas-2026', 'qatar-2026', 'abu-dhabi-2026']) {
          final outline = await TrackOutlineRepository.forRace(id);
          expect(outline, isNotNull, reason: id);
          expect(outline!.points.length, greaterThan(200));
        }
        expect(await TrackOutlineRepository.forRace('nowhere'), isNull);
      });
    });
  });

  group('live.json teamRadio', () {
    test('parses newest first and only accepts F1 static mp3 URLs', () {
      final snapshot = parseLiveJson('''
{"snapshot":{"status":"live","updatedAt":"x","positionsAvailable":true,"teamRadio":[
 {"utc":"2026-10-30T19:04:37Z","racingNumber":"67","url":"https://livetiming.formula1.com/static/2026/x/TeamRadio/A.mp3"},
 {"utc":"2026-10-30T19:08:39Z","racingNumber":"25","url":"https://livetiming.formula1.com/static/2026/x/TeamRadio/B.mp3"},
 {"utc":"2026-10-30T19:09:00Z","racingNumber":"1","url":"https://evil.example.com/a.mp3"}
]}}''')!;
      expect(snapshot.positionsAvailable, isTrue);
      expect(snapshot.teamRadio.map((r) => r.racingNumber), ['25', '67']);
    });

    test('defaults to no radio and no map for older collectors', () {
      final snapshot = parseLiveJson('{"snapshot":{"status":"live","updatedAt":"x"}}')!;
      expect(snapshot.teamRadio, isEmpty);
      expect(snapshot.positionsAvailable, isFalse);
    });
  });

  group('cards', () {
    const ham = LiveDriverPosition(
      position: 1,
      code: 'HAM',
      displayName: 'Lewis Hamilton',
      racingNumber: '44',
    );

    testWidgets('team radio card lists drivers with Korean names and a NEW badge', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 30, 19, 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveTeamRadioCard(
              radios: [
                LiveTeamRadio(
                  utc: now.subtract(const Duration(seconds: 20)),
                  racingNumber: '44',
                  url: 'https://livetiming.formula1.com/static/x/HAM.mp3',
                ),
                LiveTeamRadio(
                  utc: now.subtract(const Duration(minutes: 5)),
                  racingNumber: '99',
                  url: 'https://livetiming.formula1.com/static/x/UNK.mp3',
                ),
              ],
              drivers: const [ham],
              clock: () => now,
            ),
          ),
        ),
      );
      expect(find.text('HAM'), findsOneWidget);
      expect(find.text('루이스 해밀턴'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('#99'), findsOneWidget);
      expect(find.textContaining('04:09'), findsOneWidget); // 19:09:40Z → 04:09 KST
    });

    testWidgets('track map card draws from injected data without network', (
      tester,
    ) async {
      final controller = LivePositionsController(delaySeconds: 0, url: '');
      final w = LivePositionsWindow.tryParse(_body(t0: 0))!;
      controller.timeline.add(w);
      controller.recordOffset(w.endMs, 10000);
      final outline = TrackOutline(
        rotationDeg: 0,
        rawPoints: [
          for (var i = 0; i < 40; i++)
            Offset(i * 40.0, i < 20 ? 0 : 400),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveTrackMapCard(
              snapshot: const LiveSessionSnapshot(
                status: LiveSessionStatus.live,
                updatedAt: 'x',
                raceId: 'mexico-2026',
                positionsAvailable: true,
                classification: [ham],
              ),
              delaySeconds: 0,
              controllerOverride: controller,
              outlineOverride: outline,
              clock: () => DateTime.fromMillisecondsSinceEpoch(11000),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('트랙맵'), findsOneWidget);
      expect(find.text('차량을 탭하면 그 드라이버만 강조돼요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('track map and radio cards also show outside a session', (
      tester,
    ) async {
      // 세션 밖: 외곽선만 그리고 좌표 컨트롤러를 만들지 않는다(요청 0).
      final outline = TrackOutline(
        rotationDeg: 0,
        rawPoints: [
          for (var i = 0; i < 40; i++)
            Offset(i * 40.0, i < 20 ? 0 : 400),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                LiveTrackMapCard(
                  raceId: 'mexico-2026',
                  delaySeconds: 0,
                  outlineOverride: outline,
                ),
                const LiveTeamRadioCard(
                  radios: [],
                  drivers: [],
                  emptyMessage: '세션이 시작되면 팀 라디오가 여기에 표시돼요',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('트랙맵'), findsOneWidget);
      expect(find.text('세션 중 차량 위치 표시'), findsOneWidget);
      expect(find.text('차량을 탭하면 그 드라이버만 강조돼요'), findsNothing);
      expect(find.text('팀 라디오'), findsOneWidget);
      expect(find.text('세션이 시작되면 팀 라디오가 여기에 표시돼요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
