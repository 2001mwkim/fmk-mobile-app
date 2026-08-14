import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/drivers.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import 'live_session_controller.dart';
import 'live_session_service.dart';

/// 라이브 세션 Live Activity(잠금화면·다이나믹 아일랜드) 브리지 — iOS 전용.
///
/// 채널 계약은 ios/Runner/FmkLiveActivityManager.swift 와 수동 동기화.
/// 앱 실행 중에는 라이브 폴링에 맞춰 로컬 갱신(sync)하고, 네이티브가
/// 푸시 토큰을 collector 에 등록해 앱 종료 후에는 APNs 가 이어받는다
/// (collector: fmk-f1-calendar scripts/live-activity-push.ts).
class FmkLiveActivityBridge {
  const FmkLiveActivityBridge._();

  static const MethodChannel _channel = MethodChannel('fmk/live_activity');

  static bool _bound = false;
  static bool _configured = false;

  /// 마지막으로 활동이 떠 있던 상태 — 종료 전이를 감지해 end 를 보낸다.
  static bool _active = false;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 토큰 등록 엔드포인트 — collector(Railway) 직결.
  /// 폴링 URL(kLiveJsonUrl)은 Vercel 엣지일 수 있어 파생하면 안 된다.
  static String get _registerUrl => kLiveActivityRegisterUrl;

  static void bindTo(LiveSessionController controller) {
    if (_bound || !_isIOS) return;
    _bound = true;
    controller.addListener(() {
      unawaited(sync(snapshot: controller.snapshot));
    });
  }

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    try {
      await _channel.invokeMethod<bool>('configure', {
        'registerUrl': _registerUrl,
      });
    } catch (_) {
      // 채널 미탑재(테스트 등) — 이후 호출도 조용히 무시된다.
    }
  }

  static Future<void> sync({LiveSessionSnapshot? snapshot, DateTime? now}) async {
    if (!_isIOS) return;
    await _ensureConfigured();

    final currentTime = now ?? DateTime.now();
    final displayable =
        snapshot != null && isLiveSnapshotDisplayable(snapshot, currentTime);

    try {
      if (!displayable) {
        if (_active) {
          _active = false;
          await _channel.invokeMethod<bool>('end');
        }
        return;
      }

      _active = true;
      await _channel.invokeMethod<bool>('sync', _payload(snapshot, currentTime));
    } catch (_) {
      // 활동 실패는 라이브 기능에 영향 없음(다음 폴링에서 재시도).
    }
  }

  static Map<String, Object> _payload(
    LiveSessionSnapshot snapshot,
    DateTime now,
  ) {
    final race = resolveLiveRace(snapshot.raceId, snapshot.raceName);
    final raceLike = snapshot.isRaceOrSprint;
    final live = isLiveSnapshotSessionActive(snapshot, now);
    final drivers = snapshot.topThree
        .where((driver) => driver.code.trim().isNotEmpty)
        .take(3)
        .toList();

    String name(int index) => index < drivers.length
        ? driverNameKo(drivers[index].code, drivers[index].displayName.trim())
        : '';
    String time(int index) => index < drivers.length
        ? drivers[index].time(raceLike: raceLike).trim()
        : '';

    final kst = now.toUtc().add(const Duration(hours: 9));
    String two(int value) => value.toString().padLeft(2, '0');

    return {
      'raceId': snapshot.raceId ?? race?.id ?? '',
      'badge': live ? 'LIVE' : 'RESULT',
      'gpName': race?.nameKo ?? snapshot.raceName ?? '비아 포뮬러 라이브',
      'sessionName': snapshot.sessionTitleKo,
      'lapCurrent': raceLike ? (snapshot.currentLap ?? 0) : 0,
      'lapTotal': raceLike ? (snapshot.totalLaps ?? 0) : 0,
      'p1Name': name(0), 'p1Time': time(0),
      'p2Name': name(1), 'p2Time': time(1),
      'p3Name': name(2), 'p3Time': time(2),
      'updatedAt': '${two(kst.hour)}:${two(kst.minute)}',
    };
  }
}
