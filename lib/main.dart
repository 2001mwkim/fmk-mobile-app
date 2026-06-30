import 'package:flutter/material.dart';

import 'app.dart';
import 'services/live_session_controller.dart';

void main() {
  // 실데이터 폴링 활성화(테스트는 FmkApp 을 직접 띄워 비활성 상태 유지).
  liveSessionController.enabled = true;
  runApp(const FmkApp());
}
