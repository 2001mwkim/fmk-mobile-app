import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/fmk_home_widget_bridge.dart';
import 'services/live_session_controller.dart';
import 'services/notification_settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  liveSessionController.enabled = true;
  FmkHomeWidgetBridge.bindTo(liveSessionController);
  unawaited(
    FmkHomeWidgetBridge.update(snapshot: liveSessionController.snapshot),
  );
  unawaited(notificationSettingsController.refreshScheduledNotifications());
  runApp(const FmkApp());
}
