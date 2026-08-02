import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/fmk_live_activity_bridge.dart';
import 'services/live_session_controller.dart';
import 'services/notification_settings_controller.dart';

/// 크래시 리포팅 DSN. 릴리스 빌드에 `--dart-define=SENTRY_DSN=...` 로 주입한다.
/// 비어 있으면 Sentry 를 아예 초기화하지 않아(테스트/로컬/DSN 미설정) 완전한
/// no-op 이 된다. 값이 있어야만 크래시가 수집된다.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// WorkManager 주기 작업 이름(변경 시 기존 등록과 충돌하지 않게 유지).
const String _kWidgetRefreshUniqueName = 'fmk-widget-refresh';
const String _kWidgetRefreshTaskName = 'fmkWidgetRefresh';

/// 백그라운드 isolate 진입점 — 앱이 실행 중이 아니어도 WorkManager 가
/// 이 함수를 호출해 위젯 데이터(라이브/확정 결과/다음 일정)를 갱신한다.
/// vm:entry-point 가 없으면 릴리스(AOT) 빌드에서 트리 셰이킹으로 사라진다.
@pragma('vm:entry-point')
void fmkWidgetBackgroundDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await FmkHomeWidgetBridge.refreshFromNetwork();
      return true;
    } catch (_) {
      // 실패해도 재시도 폭주를 피하기 위해 성공 처리(다음 주기에 다시 시도).
      return true;
    }
  });
}

/// 위젯 자체 갱신 주기. 결과/일정은 자주 안 바뀌므로 30분이면 충분하고,
/// 라이브 중 실시간성은 앱 실행 시의 폴링(LiveSessionController)이 담당한다.
Future<void> _registerWidgetBackgroundRefresh() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(fmkWidgetBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _kWidgetRefreshUniqueName,
      _kWidgetRefreshTaskName,
      frequency: const Duration(minutes: 30),
      // 이미 등록돼 있으면 유지(앱 실행마다 재등록으로 주기 리셋 방지).
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (error) {
    debugPrint('Failed to register widget background refresh: $error');
  }
}

void main() {
  // DSN 이 없으면 Sentry 초기화 비용/후킹 없이 바로 실행한다.
  if (_sentryDsn.isEmpty) {
    _bootstrap();
    return;
  }

  // Sentry 가 FlutterError.onError 후킹과 가드 존 설정을 담당하고, appRunner
  // 안에서 앱을 실행해 초기화 이후의 미처리 예외까지 수집한다.
  unawaited(
    SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        // 스택트레이스 심볼화를 위한 릴리스 식별자(빌드마다 갱신).
        options.release = 'fmk_app@0.1.1+20';
        // 크래시(에러) 수집이 목적이라 성능 트레이싱은 끈다(쿼터/오버헤드 절약).
        options.tracesSampleRate = 0.0;
      },
      appRunner: _bootstrap,
    ),
  );
}

/// 앱 부팅(라이브 폴링·위젯 브리지·알림 재등록 후 runApp). Sentry 초기화
/// 여부와 무관하게 동일한 시작 절차를 공유한다.
void _bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  liveSessionController.enabled = true;
  FmkHomeWidgetBridge.bindTo(liveSessionController);
  // iOS Live Activity(잠금화면·다이나믹 아일랜드) — 라이브 폴링과 동기화.
  FmkLiveActivityBridge.bindTo(liveSessionController);
  unawaited(
    FmkHomeWidgetBridge.update(snapshot: liveSessionController.snapshot),
  );
  unawaited(FmkLiveActivityBridge.sync(snapshot: liveSessionController.snapshot));
  unawaited(_registerWidgetBackgroundRefresh());
  unawaited(notificationSettingsController.refreshScheduledNotifications());
  runApp(const FmkApp());
}
