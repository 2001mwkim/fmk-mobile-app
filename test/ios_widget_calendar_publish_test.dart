import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
