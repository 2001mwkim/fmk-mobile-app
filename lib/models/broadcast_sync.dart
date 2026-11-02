import 'live_session.dart';

/// 중계 싱크 맞추기 — 사용자가 "중계 화면에서 무언가가 바뀐 순간" 버튼을 누른
/// 시각과, 실제(실시간 데이터)로 그 일이 일어난 시각의 차이를 영상 지연으로 쓴다.
///
/// 쿠팡플레이 등 중계 지연은 기기·네트워크·화질마다 달라 고정 프리셋으로는 맞지
/// 않는다(2026-11 결정). 기준점은 두 가지:
/// - 레이스/스프린트: 선두가 새 랩에 들어간 순간(중계 화면 랩 카운터가 바뀜).
///   collector `recentLapStarts` 의 수신 시각을 쓴다.
/// - 연습/퀄리파잉: 세션 남은 시간 시계가 정각 분(예: 12:00)이 되는 순간.
///   스냅샷의 `remainingTime` 은 `updatedAt` 시점 값이라 거기서 역산한다.
///
/// 기기 시계와 collector 시계의 차이(보통 NTP 로 1초 이내)는 보정하지 않는다.
const int kMaxBroadcastDelaySeconds = 120;

/// "HH:MM:SS" 또는 "MM:SS" → Duration. 형식이 다르면 null.
Duration? parseSessionClock(String? value) {
  if (value == null) return null;
  final parts = value.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0)) return null;
  final h = parts.length == 3 ? numbers[0]! : 0;
  final m = numbers[parts.length - 2]!;
  final s = numbers[parts.length - 1]!;
  return Duration(hours: h, minutes: m, seconds: s);
}

/// 계산된 지연이 앱이 지원하는 범위(0~120초)면 반올림한 초, 아니면 null.
/// 음수는 "중계가 데이터보다 빠르다" 는 뜻이라 탭 실수로 보고 거절한다.
int? _acceptDelay(Duration delay) {
  final seconds = (delay.inMilliseconds / 1000).round();
  if (seconds < 0 || seconds > kMaxBroadcastDelaySeconds) return null;
  return seconds;
}

/// 랩 기준: 중계 화면이 [tvLap] 으로 바뀐 순간 [tappedAt] 에 눌렀을 때의 지연.
/// 해당 랩의 시작 시각을 모르거나 범위를 벗어나면 null.
int? delayFromLapTap({
  required DateTime tappedAt,
  required int tvLap,
  required List<LiveLapStart> lapStarts,
}) {
  for (final start in lapStarts) {
    if (start.lap == tvLap) return _acceptDelay(tappedAt.difference(start.at));
  }
  return null;
}

/// 랩 기준 기본 추정 랩: 누른 시각 이전에 시작한 랩 중 가장 최근 것.
/// 지연이 한 랩보다 길면 실제론 그 이전 랩일 수 있어 화면에서 ± 로 고치게 한다.
int? defaultTvLap({
  required DateTime tappedAt,
  required List<LiveLapStart> lapStarts,
}) {
  int? lap;
  for (final start in lapStarts) {
    if (!start.at.isAfter(tappedAt)) lap = start.lap;
  }
  return lap;
}

/// 시계 기준 목표값: 지금 실제 남은 시간 이하의 가장 가까운 정각 분.
/// 중계는 실제보다 늦으므로(남은 시간이 더 많이 보임) 중계 화면은 아직 이
/// 값에 도달하지 않았다. 1분 미만 남았거나 계산 불가면 null.
Duration? clockSyncTarget({
  required DateTime now,
  required DateTime snapshotAt,
  required Duration snapshotRemaining,
}) {
  final realRemaining = snapshotRemaining - now.difference(snapshotAt);
  if (realRemaining < const Duration(minutes: 1)) return null;
  return Duration(minutes: realRemaining.inMinutes);
}

/// 시계 기준: 중계 화면 남은 시간이 [target] 이 된 순간 [tappedAt] 에 눌렀을 때의 지연.
/// 실제 시계가 target 에 닿은 시각 = snapshotAt + (snapshotRemaining - target).
int? delayFromClockTap({
  required DateTime tappedAt,
  required Duration target,
  required DateTime snapshotAt,
  required Duration snapshotRemaining,
}) {
  final realHitAt = snapshotAt.add(snapshotRemaining - target);
  return _acceptDelay(tappedAt.difference(realHitAt));
}

/// 화면 표시용 "12:00" (시간이 있으면 "1:05:00").
String formatSessionClock(Duration value) {
  final h = value.inHours;
  final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
