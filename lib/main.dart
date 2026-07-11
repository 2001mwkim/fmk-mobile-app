import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/live_session_controller.dart';
import 'services/notification_settings_controller.dart';

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
  WidgetsFlutterBinding.ensureInitialized();
  liveSessionController.enabled = true;
  FmkHomeWidgetBridge.bindTo(liveSessionController);
  unawaited(
    FmkHomeWidgetBridge.update(snapshot: liveSessionController.snapshot),
  );
  unawaited(_registerWidgetBackgroundRefresh());
  unawaited(notificationSettingsController.refreshScheduledNotifications());
  runApp(const FmkApp());
}
