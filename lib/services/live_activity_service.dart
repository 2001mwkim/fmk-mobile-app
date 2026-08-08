import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/live_session.dart';
import 'live_session_controller.dart';
import 'live_session_service.dart' show kLiveJsonUrl;

/// Android 16 Live Update(삼성 One UI Now Bar) 라이브 액티비티 브리지.
///
/// 라이브 세션이 "라이브 레이스/스프린트"가 되면 네이티브 포그라운드 서비스를
/// 켜고(그 서비스가 live.json 을 직접 폴링하며 앱이 꺼져도 갱신), 그렇지 않게
/// 되면 끈다. Android 외 플랫폼/웹에서는 전부 no-op.
///
/// v1 범위: 레이스/스프린트만(랩 진행 바 기반). 프랙티스/퀄리는 제외.
class LiveActivityBridge {
  const LiveActivityBridge._();

  static const MethodChannel _channel = MethodChannel('fmk/live_activity');

  /// Now Bar(Android FGS) 기능 스위치. 현재는 삼성이 서드파티 Live Update 를
  /// 기본 차단해 실사용자 노출이 안 되고, FGS_DATA_SYNC 권한이 Play 선언(동영상)
  /// 부담을 유발하므로 릴리스에서 비활성화한다. 삼성 개방/화이트리스트 등재 시
  /// true 로 되돌리고 AndroidManifest 의 FGS 권한·서비스 선언을 복구하면 된다.
  static const bool _enabled = false;

  static final bool _supported = _enabled &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  /// 중복 start/stop 호출을 막는 현재 활성 상태(앱 프로세스 기준).
  static bool _active = false;

  /// [liveSessionController] 를 구독해 라이브 세션 상태에 맞춰 서비스를 켜고 끈다.
  /// main() 에서 1회 호출.
  static void bindTo(LiveSessionController controller) {
    if (!_supported) return;
    controller.addListener(() => _sync(controller.snapshot));
    _sync(controller.snapshot);
  }

  static void _sync(LiveSessionSnapshot? snapshot) {
    final isLiveRace = snapshot != null &&
        snapshot.isRaceOrSprint &&
        isLiveSnapshotSessionActive(snapshot);
    if (isLiveRace) {
      _start();
    } else {
      _stop();
    }
  }

  static Future<void> _start() async {
    if (!_supported || _active) return;
    _active = true;
    try {
      await _channel.invokeMethod<void>('start', {'liveJsonUrl': kLiveJsonUrl});
    } catch (_) {
      // 채널 실패 시 다음 상태 변화에서 다시 시도할 수 있게 롤백.
      _active = false;
    }
  }

  static Future<void> _stop() async {
    if (!_supported || !_active) return;
    _active = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // 실패해도 상태는 비활성 유지(네이티브 서비스는 스스로도 종료됨).
    }
  }

  /// 개발 검증용: 실제 라이브 세션 없이 정적 데이터로 Now Bar 알림을 띄운다.
  /// 디버그 빌드의 설정 화면 버튼에서만 호출한다(_sync 의 _active 와 무관하게
  /// 동작하도록 _active 를 건드리지 않는다 — 컨트롤러 갱신이 데모를 끄지 않게).
  static Future<void> debugStartDemo() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('startDemo');
    } catch (_) {}
  }

  /// 데모/라이브 액티비티를 강제 종료(디버그 버튼용).
  static Future<void> debugStop() async {
    if (!_supported) return;
    _active = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
