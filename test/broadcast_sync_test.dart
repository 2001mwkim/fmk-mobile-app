import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/broadcast_sync.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/live_session_service.dart';
import 'package:fmk_app/widgets/broadcast_sync_sheet.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 1, 20, 0, 0);
  final starts = [
    LiveLapStart(lap: 21, at: t0),
    LiveLapStart(lap: 22, at: t0.add(const Duration(seconds: 80))),
    LiveLapStart(lap: 23, at: t0.add(const Duration(seconds: 161))),
  ];

  group('랩 기준', () {
    test('중계가 바뀐 순간과 랩 시작 시각의 차이가 지연이다', () {
      final tapped = t0.add(const Duration(seconds: 80 + 37, milliseconds: 400));
      expect(
        delayFromLapTap(tappedAt: tapped, tvLap: 22, lapStarts: starts),
        37,
      );
    });

    test('기본 추정 랩은 누르기 전에 시작한 가장 최근 랩', () {
      final tapped = t0.add(const Duration(seconds: 100));
      expect(defaultTvLap(tappedAt: tapped, lapStarts: starts), 22);
    });

    test('범위 밖(음수·120초 초과)이거나 모르는 랩이면 null', () {
      final tapped = t0.add(const Duration(seconds: 10));
      expect(
        delayFromLapTap(tappedAt: tapped, tvLap: 22, lapStarts: starts),
        isNull,
      );
      expect(
        delayFromLapTap(
          tappedAt: t0.add(const Duration(seconds: 200)),
          tvLap: 21,
          lapStarts: starts,
        ),
        isNull,
      );
      expect(
        delayFromLapTap(tappedAt: tapped, tvLap: 5, lapStarts: starts),
        isNull,
      );
    });
  });

  group('시계 기준', () {
    test('세션 시계 문자열을 읽는다', () {
      expect(parseSessionClock('00:18:42'), const Duration(minutes: 18, seconds: 42));
      expect(parseSessionClock('12:05'), const Duration(minutes: 12, seconds: 5));
      expect(parseSessionClock('abc'), isNull);
      expect(parseSessionClock(null), isNull);
    });

    test('목표는 지금 실제 남은 시간 이하의 정각 분', () {
      final target = clockSyncTarget(
        now: t0.add(const Duration(seconds: 10)),
        snapshotAt: t0,
        snapshotRemaining: const Duration(minutes: 12, seconds: 30),
      );
      expect(target, const Duration(minutes: 12));
      expect(
        clockSyncTarget(
          now: t0,
          snapshotAt: t0,
          snapshotRemaining: const Duration(seconds: 40),
        ),
        isNull,
      );
    });

    test('실제 시계가 목표에 닿은 시각부터 누른 시각까지가 지연', () {
      // 실제 시계는 t0+30초에 12:00 을 지난다. 중계는 45초 늦게 12:00 을 보여준다.
      final tapped = t0.add(const Duration(seconds: 75));
      expect(
        delayFromClockTap(
          tappedAt: tapped,
          target: const Duration(minutes: 12),
          snapshotAt: t0,
          snapshotRemaining: const Duration(minutes: 12, seconds: 30),
        ),
        45,
      );
      expect(formatSessionClock(const Duration(minutes: 12)), '12:00');
    });
  });

  test('live.json recentLapStarts 를 오름차순으로 읽고 깨진 항목은 건너뛴다', () {
    final snapshot = parseLiveJson('''
      {"snapshot": {"status": "live", "updatedAt": "2026-11-01T20:00:00Z",
        "recentLapStarts": [
          {"lap": 23, "at": "2026-11-01T20:02:41Z"},
          {"lap": 22, "at": "2026-11-01T20:01:20Z"},
          {"lap": "x", "at": "2026-11-01T20:00:00Z"}
        ]}}
    ''');
    expect(snapshot!.recentLapStarts.map((s) => s.lap), [22, 23]);
    expect(
      parseLiveJson('{"snapshot": {"status": "live", "updatedAt": ""}}')!
          .recentLapStarts,
      isEmpty,
    );
  });

  testWidgets('레이스 중 버튼을 누르면 측정값을 보여주고 랩을 고칠 수 있다', (tester) async {
    var now = t0.add(const Duration(seconds: 80 + 37));
    final snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: t0.toIso8601String(),
      sessionType: 'Race',
      recentLapStarts: starts,
    );
    int? popped;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BroadcastSyncSheet(
                    readSnapshot: () => snapshot,
                    refresh: () async {},
                    clock: () => now,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('지금 바뀌었어요'));
    await tester.pumpAndSettle();
    expect(find.text('37초'), findsOneWidget);
    expect(find.text('중계에 나온 랩 22'), findsOneWidget);

    // 한 랩 전으로 고치면 117초.
    await tester.tap(find.byTooltip('한 랩 전'));
    await tester.pumpAndSettle();
    expect(find.text('117초'), findsOneWidget);

    await tester.tap(find.text('이 지연으로 보기'));
    await tester.pumpAndSettle();
    expect(popped, 117);
    now = t0;
  });

  testWidgets('세션이 진행 중이 아니면 안내만 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BroadcastSyncSheet(
            readSnapshot: () => null,
            refresh: () async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('세션이 진행 중일 때만'), findsOneWidget);
    expect(find.text('지금 바뀌었어요'), findsNothing);
  });
}
