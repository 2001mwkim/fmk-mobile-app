import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// 라이브 트랙맵의 서킷 외곽선(2026-10).
///
/// 기존 `assets/circuits` SVG 는 F1 좌표계와 축척·방향이 달라 차량 좌표를 얹을
/// 수 없어서, F1 아카이브의 실제 1랩 궤적으로 만든 외곽선을 따로 둔다.
/// 생성: collector 저장소 `npm run track-outlines` → `assets/track_outlines.json`
/// (24개 서킷, 공식 서킷 길이와 1~2% 이내로 일치하는 것 확인).
class TrackOutline {
  TrackOutline({required this.rotationDeg, required List<Offset> rawPoints})
    : _cos = math.cos(rotationDeg * math.pi / 180),
      _sin = math.sin(rotationDeg * math.pi / 180) {
    points = [for (final p in rawPoints) project(p)];
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final p in points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
      top = math.min(top, p.dy);
      bottom = math.max(bottom, p.dy);
    }
    bounds = Rect.fromLTRB(left, top, right, bottom);
  }

  /// 화면을 가로로 길게 쓰는 회전각(생성 스크립트가 계산).
  final double rotationDeg;
  final double _cos;
  final double _sin;

  /// 회전을 적용한 외곽선(화면 좌표계 — y 가 아래로 증가).
  late final List<Offset> points;
  late final Rect bounds;

  /// F1 원본 좌표 → 외곽선과 같은 회전 좌표. 생성 스크립트와 같은 식이어야 한다:
  /// X = x·cos − y·sin, Y = −(x·sin + y·cos).
  Offset project(Offset raw) => Offset(
    raw.dx * _cos - raw.dy * _sin,
    -(raw.dx * _sin + raw.dy * _cos),
  );

  static TrackOutline? fromJson(Object? json) {
    if (json is! Map) return null;
    final rotation = json['rotation'];
    final rawPoints = json['points'];
    if (rotation is! num || rawPoints is! List || rawPoints.length < 20) {
      return null;
    }
    final pts = <Offset>[];
    for (final p in rawPoints) {
      if (p is List && p.length == 2 && p[0] is num && p[1] is num) {
        pts.add(Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()));
      }
    }
    if (pts.length < 20) return null;
    return TrackOutline(rotationDeg: rotation.toDouble(), rawPoints: pts);
  }
}

/// 에셋을 한 번만 읽어 raceId 별로 캐시한다.
class TrackOutlineRepository {
  TrackOutlineRepository._();

  static Map<String, TrackOutline>? _cache;
  static Future<Map<String, TrackOutline>>? _loading;

  static Future<TrackOutline?> forRace(String? raceId) async {
    if (raceId == null || raceId.isEmpty) return null;
    final all = _cache ?? await (_loading ??= _load());
    return all[raceId];
  }

  static Future<Map<String, TrackOutline>> _load() async {
    try {
      final body = await rootBundle.loadString('assets/track_outlines.json');
      final decoded = jsonDecode(body);
      final outlines = decoded is Map ? decoded['outlines'] : null;
      final result = <String, TrackOutline>{};
      if (outlines is Map) {
        outlines.forEach((key, value) {
          final outline = TrackOutline.fromJson(value);
          if (outline != null) result['$key'] = outline;
        });
      }
      return _cache = result;
    } catch (_) {
      // 에셋이 없거나 깨져도 라이브 센터는 지도 카드만 빼고 정상 동작한다.
      return _cache = const {};
    }
  }
}
