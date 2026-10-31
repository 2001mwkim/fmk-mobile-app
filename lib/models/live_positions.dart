import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

/// collector `/positions.json` 한 묶음(2026-10).
///
/// 최근 6초를 2Hz 로 솎은 22대 좌표. 앱은 3초마다 받아 [LivePositionTimeline]
/// 에 이어 붙이고, 몇 초 뒤처진 시각을 보간 재생한다(설계: collector
/// `lib/live/positionFeed.ts`). 좌표는 F1 원본 단위(≈0.1m)다.
class LivePositionsWindow {
  const LivePositionsWindow({
    required this.t0,
    required this.dt,
    required this.count,
    required this.cars,
  });

  /// 첫 프레임 시각(epoch ms, F1 타임스탬프).
  final int t0;
  final int dt;
  final int count;

  /// 차량 번호 → [x0, y0, x1, y1, …]. 그 시점 좌표가 없으면 null 쌍.
  final Map<String, List<double?>> cars;

  int get endMs => t0 + (count - 1) * dt;

  /// 본문 파싱. `available:false`·형식 오류면 null. 예외를 던지지 않는다.
  static LivePositionsWindow? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['available'] != true) return null;
      final t0 = decoded['t0'];
      final dt = decoded['dt'];
      final count = decoded['count'];
      final rawCars = decoded['cars'];
      if (t0 is! num || dt is! num || count is! num || rawCars is! Map) {
        return null;
      }
      if (dt <= 0 || count <= 0 || count > 200) return null;
      final cars = <String, List<double?>>{};
      for (final entry in rawCars.entries.take(40)) {
        final list = entry.value;
        if (list is! List || list.length != count * 2) continue;
        cars['${entry.key}'] = [
          for (final v in list) v is num ? v.toDouble() : null,
        ];
      }
      return LivePositionsWindow(
        t0: t0.toInt(),
        dt: dt.toInt(),
        count: count.toInt(),
        cars: cars,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 받은 묶음들을 시각순으로 이어 붙이고, 임의 시각의 위치를 보간해 준다.
class LivePositionTimeline {
  LivePositionTimeline({this.retention = const Duration(seconds: 30)});

  final Duration retention;
  final SplayTreeMap<int, Map<String, Offset>> _frames =
      SplayTreeMap<int, Map<String, Offset>>();

  /// 0.5초 사이에 이보다 더 움직이면(≈ 시속 1,000km) 추적이 튄 것으로 보고
  /// 보간하지 않는다(피트 진입·좌표 재설정 등).
  static const double _maxStep = 1500;

  bool get isEmpty => _frames.isEmpty;
  int? get latestMs => _frames.isEmpty ? null : _frames.lastKey();

  void clear() => _frames.clear();

  void add(LivePositionsWindow window) {
    for (var i = 0; i < window.count; i++) {
      final frame = <String, Offset>{};
      window.cars.forEach((number, flat) {
        final x = flat[i * 2];
        final y = flat[i * 2 + 1];
        if (x != null && y != null) frame[number] = Offset(x, y);
      });
      _frames[window.t0 + i * window.dt] = frame;
    }
    final latest = _frames.lastKey();
    if (latest == null) return;
    final cutoff = latest - retention.inMilliseconds;
    while (_frames.isNotEmpty && _frames.firstKey()! < cutoff) {
      _frames.remove(_frames.firstKey());
    }
  }

  /// [timeMs] 시점의 차량 위치. 데이터 범위를 벗어나면 가장 가까운 끝 프레임에
  /// 멈춘다(외삽하지 않는다 — 늦게 오면 제자리에 서 있는 편이 안전하다).
  Map<String, Offset> sample(int timeMs) {
    if (_frames.isEmpty) return const {};
    final before = _frames.containsKey(timeMs)
        ? timeMs
        : _frames.lastKeyBefore(timeMs);
    final after = _frames.firstKeyAfter(timeMs);
    if (before == null) return _frames[_frames.firstKey()]!;
    if (after == null) return _frames[before]!;
    final a = _frames[before]!;
    final b = _frames[after]!;
    final k = (timeMs - before) / (after - before);
    final out = <String, Offset>{};
    a.forEach((number, pa) {
      final pb = b[number];
      if (pb == null || (pb - pa).distance > _maxStep) {
        out[number] = pa;
      } else {
        out[number] = Offset.lerp(pa, pb, k)!;
      }
    });
    return out;
  }
}
