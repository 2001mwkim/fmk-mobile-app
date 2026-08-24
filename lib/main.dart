import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:home_widget/home_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/fmk_live_activity_bridge.dart';
import 'services/live_activity_service.dart';
import 'services/live_session_controller.dart';
import 'services/notification_settings_controller.dart';

/// 릴리스(AOT product) 빌드 여부 — 릴리스 기본값 상수 선택용.
const bool _kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');

/// 크래시 리포팅 DSN. 릴리스는 프로덕션 DSN 이 기본값(주입을 잊어도 크래시
/// 가시성이 꺼지지 않게 — 라이브 URL 과 같은 원칙), debug/profile/테스트는
/// 빈 값이라 Sentry 를 아예 초기화하지 않는 완전한 no-op 이다.
/// `--dart-define=SENTRY_DSN=...` 로 언제든 덮어쓸 수 있다.
/// DSN 은 클라이언트 공개 키라 커밋해도 안전하다.
const String _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: _kIsReleaseBuild
      ? 'https://8f227640e3c22f90eba314ad044339f1@o4511880011120640.ingest.us.sentry.io/4511880013479936'
      : '',
);

/// EventChannel(예: home_widget/updates) 스트림 해제 경합으로 나는 무해한
/// "No active stream to cancel" 인지 판별. 프레임워크가 FlutterError 로 재보고
/// 하므로 throwable 이 유실될 수 있어 exceptions 값 문자열도 함께 확인한다.
bool _isBenignStreamCancel(SentryEvent event) {
  final throwable = event.throwable;
  if (throwable is PlatformException &&
      (throwable.message?.contains('No active stream to cancel') ?? false)) {
    return true;
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value?.contains('No active stream to cancel') ?? false) {
      return true;
    }
  }
  return false;
}

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
      final installed = await HomeWidget.getInstalledWidgets();
      final needsStandings = installed.any((widget) {
        final name = widget.androidClassName ?? '';
        return name.endsWith('FmkStandingsWidgetProvider') ||
            name.endsWith('FmkConstructorStandingsWidgetProvider') ||
            name.endsWith('FmkMyDriverWidgetProvider') ||
            name.endsWith('FmkMyTeamWidgetProvider');
      });
      if (needsStandings) {
        await FmkHomeWidgetBridge.refreshStandingsFromNetwork();
      }
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
      frequency: const Duration(hours: 6),
      // 기존 30분 작업도 새 6시간 정책으로 교체한다.
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
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
    SentryFlutter.init((options) {
      options.dsn = _sentryDsn;
      // release/dist 는 sentry_flutter 가 패키지 정보(버전·빌드번호)에서 자동
      // 감지하게 둔다(하드코딩 시 실제 버전과 어긋나 크래시가 오분류됨).
      // 크래시(에러) 수집이 목적이라 성능 트레이싱은 끈다(쿼터/오버헤드 절약).
      options.tracesSampleRate = 0.0;
      // 무해한 프레임워크 노이즈 필터링(실제 크래시 아님). home_widget 등
      // EventChannel 스트림 해제 시 나는 "No active stream to cancel" 은
      // 프레임워크가 내부에서 잡아 FlutterError.reportError 로 재보고하므로
      // 앱 코드의 try/catch·cancel().catchError 로는 막을 수 없다. 여기서만
      // 확실히 제외해 fatal 오집계를 막는다.
      options.beforeSend = (event, hint) {
        if (_isBenignStreamCancel(event)) return null;
        return event;
      };
    }, appRunner: _bootstrap),
  );
}

/// 앱 부팅(라이브 폴링·위젯 브리지·알림 재등록 후 runApp). Sentry 초기화
/// 여부와 무관하게 동일한 시작 절차를 공유한다.
void _bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  liveSessionController.attachLifecycle();
  liveSessionController.enabled = true;
  // iOS Live Activity(잠금화면·다이나믹 아일랜드) — 라이브 폴링과 동기화.
  FmkLiveActivityBridge.bindTo(liveSessionController);
  // 라이브 세션 중 Android Now Bar(Live Update) 서비스를 켜고 끈다(Android 전용).
  LiveActivityBridge.bindTo(liveSessionController);
  unawaited(
    FmkHomeWidgetBridge.update(snapshot: liveSessionController.snapshot),
  );
  unawaited(
    FmkLiveActivityBridge.sync(snapshot: liveSessionController.snapshot),
  );
  unawaited(_registerWidgetBackgroundRefresh());
  unawaited(notificationSettingsController.refreshScheduledNotifications());
  runApp(const FmkApp());
}
