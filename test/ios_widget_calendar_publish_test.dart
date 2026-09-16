import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/race_results_repository.dart';
import 'package:fmk_app/services/standings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iOS publishes the entire calendar while network data is still pending',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('home_widget');
      final calls = <MethodCall>[];
      final network = _PendingStandings();
      final oldStandings = FmkHomeWidgetBridge.standingsRepository;
      final oldResults = FmkHomeWidgetBridge.resultsRepository;
      FmkHomeWidgetBridge.standingsRepository = network;
      FmkHomeWidgetBridge.resultsRepository = _OfflineResults();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        FmkHomeWidgetBridge.standingsRepository = oldStandings;
        FmkHomeWidgetBridge.resultsRepository = oldResults;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final update = FmkHomeWidgetBridge.update();
      try {
        await network.started.future;
        final saved = calls.singleWhere(
          (call) =>
              call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == 'scheduleCalendarV1',
        );
        expect(
          (saved.arguments as Map)['data'],
          buildFmkWidgetScheduleCalendar(),
        );
        expect(calls.last.method, 'updateWidget');
        expect((calls.last.arguments as Map)['ios'], fmkHomeWidgetIOSKind);
        expect(network.response.isCompleted, isFalse);
      } finally {
        network.response.complete(null);
        await update;
      }
    },
  );

  // FmkScheduleCalendar.decode 는 한 GP 라도 아래 조건을 어기면 시즌 전체를
  // 버리고 구버전 단일 GP 데이터로 조용히 되돌아간다(위젯이 스스로 다음 GP 로
  // 넘어가지 못하게 됨). 정적 일정을 고칠 때 그 폴백을 눈치채지 못하는 일이
  // 없도록 실제 데이터로 같은 조건을 검사한다. 특히 endEpochMs 는
  // getRaceWeekendEndDate 가 '레이스 세션 종료'를 주므로, 레이스가 주말의
  // 마지막 세션이 아니게 되면 여기서 먼저 깨진다.
  test('real season calendar satisfies the iOS decoder invariants', () {
    final calendar =
        jsonDecode(buildFmkWidgetScheduleCalendar()) as Map<String, dynamic>;
    expect(calendar['version'], 1);

    final calendarRaces = (calendar['races'] as List)
        .cast<Map<String, dynamic>>();
    expect(calendarRaces, isNotEmpty);
    expect(
      calendarRaces.length,
      races.where((race) => !race.isCancelled).length,
      reason: '취소되지 않은 GP 는 모두 캘린더에 실려야 한다',
    );

    for (final race in calendarRaces) {
      final id = race['id'] as String;
      final raceEnd = (race['endEpochMs'] as num).toDouble();
      final sessions = (race['sessions'] as List).cast<Map<String, dynamic>>();

      expect(id, isNotEmpty);
      expect(raceEnd, greaterThan(0));
      expect(sessions, isNotEmpty, reason: '$id 에 세션이 없다');
      expect(
        sessions.length,
        lessThanOrEqualTo(5),
        reason: '$id 세션이 5개를 넘는다 — 위젯이 캘린더 전체를 버린다',
      );

      for (final session in sessions) {
        final start = (session['startEpochMs'] as num).toDouble();
        final end = (session['endEpochMs'] as num).toDouble();
        expect(start, greaterThan(0), reason: '$id/${session['id']}');
        expect(end, greaterThan(start), reason: '$id/${session['id']}');
        expect(
          end,
          lessThanOrEqualTo(raceEnd),
          reason:
              '$id/${session['id']} 종료가 GP 종료보다 늦다 — '
              '레이스가 주말 마지막 세션인지 확인할 것',
        );
      }
    }
  });
}

class _PendingStandings implements StandingsRepository {
  final started = Completer<void>();
  final response = Completer<StandingsSnapshot?>();

  @override
  Future<StandingsSnapshot?> fetchLatest() {
    started.complete();
    return response.future;
  }
}

class _OfflineResults extends HttpRaceResultsRepository {
  @override
  Future<LatestRaceResult?> fetchLatest({int season = 2026}) async => null;
}
