import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/live_session.dart';
import 'live_session_service.dart';

/// live.json 을 주기적으로 폴링해 최신 [LiveSessionSnapshot] 을 제공한다.
///
/// - 리스너(화면)가 처음 붙으면 폴링을 시작하고, 모두 떨어지면 타이머를 정리한다.
/// - 표시 가능한(isDisplayable) 스냅샷만 노출하고, 그 외에는 null(라이브 UI 숨김).
/// - 네트워크/파싱 실패 시 null 로 두어 라이브 UI 만 숨기고 앱은 그대로 유지한다.
/// - [enabled] 가 false 면 폴링하지 않는다(위젯 테스트에서 네트워크 차단용).
class LiveSessionController extends ChangeNotifier {
  LiveSessionController(this._service);

  final LiveSessionService _service;

  /// 폴링 주기(15~30초 권장).
  static const Duration pollInterval = Duration(seconds: 20);

  /// 실제 폴링 활성화 여부. main() 에서 true 로 켠다(테스트에서는 기본 false).
  bool enabled = false;

  LiveSessionSnapshot? _snapshot;
  LiveSessionSnapshot? get snapshot => _snapshot;

  Timer? _timer;
  int _listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    if (_listeners == 1) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners <= 0) _stop();
  }

  void _start() {
    if (!enabled || _timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final fetched = await _service.fetch();
    // 표시 가능한 스냅샷만 노출(웹 useLiveSession 게이트와 동일).
    final next = (fetched != null && fetched.isDisplayable) ? fetched : null;
    if (next == _snapshot) return;
    _snapshot = next;
    notifyListeners();
  }

  /// 외부에서 즉시 1회 갱신이 필요할 때.
  Future<void> refresh() => _poll();
}

/// 앱 전역 컨트롤러(단일 타이머). main() 에서 enabled = true 로 켠다.
final LiveSessionController liveSessionController = LiveSessionController(
  const LiveSessionService(),
);
