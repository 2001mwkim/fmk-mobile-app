import 'dart:convert';

import 'package:http/http.dart' as http;

// Position.z 실험용 디버그 서비스 (2026-09 POC).
//
// **프로덕션 기능이 아니다.** 기존 LiveSessionService/LiveSessionController 와
// 완전히 분리돼 있고, 디버그 빌드의 Position 실험 화면에서만 쓴다.
// 기존 라이브 폴링·Cloudflare 캐시·Live Activity 경로에는 일절 관여하지 않는다.
//
// collector 의 `/debug/position` 을 읽는다(no-store, 프로덕션 앱은 호출 안 함).

/// 비교할 전송 주기. 서버의 SAMPLING_MODES 와 문자열이 일치해야 한다.
enum PositionSamplingMode {
  raw('raw', 'RAW'),
  hz5('5hz', '5 Hz'),
  hz2('2hz', '2 Hz'),
  hz1('1hz', '1 Hz');

  const PositionSamplingMode(this.query, this.label);

  /// `?mode=` 쿼리 값.
  final String query;

  /// 화면 표기.
  final String label;

  /// 이 모드에서 기대되는 갱신 간격(보간 구간 길이의 기준).
  Duration get expectedInterval => switch (this) {
    PositionSamplingMode.raw => const Duration(milliseconds: 250),
    PositionSamplingMode.hz5 => const Duration(milliseconds: 200),
    PositionSamplingMode.hz2 => const Duration(milliseconds: 500),
    PositionSamplingMode.hz1 => const Duration(seconds: 1),
  };
}

/// 차량 1대의 위치(서버 정규화 결과와 1:1).
class PositionEntry {
  const PositionEntry({
    required this.racingNumber,
    required this.x,
    required this.y,
    this.z,
    this.status,
  });

  final String racingNumber;
  final double x;
  final double y;
  final double? z;
  final String? status;

  static PositionEntry? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final number = raw['racingNumber'];
    final x = _toDouble(raw['x']);
    final y = _toDouble(raw['y']);
    if (number is! String || x == null || y == null) return null;
    return PositionEntry(
      racingNumber: number,
      x: x,
      y: y,
      z: _toDouble(raw['z']),
      status: raw['status'] is String ? raw['status'] as String : null,
    );
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// `/debug/position` 한 번의 응답.
class PositionSnapshot {
  const PositionSnapshot({
    required this.enabled,
    required this.mock,
    required this.mode,
    required this.positions,
    this.timestamp,
    this.decodeStrategy,
    this.driverCount = 0,
    this.rawUpdatesPerSecond = 0,
    this.lastUpdateAgeMs,
    this.payloadBytes = 0,
    this.fetchMs = 0,
  });

  /// 서버에서 실험이 켜져 있는지(`POSITION_EXPERIMENT=1`).
  final bool enabled;

  /// 합성 피더 데이터인지 — 실제 세션 측정과 구분하기 위한 표시.
  final bool mock;

  final String mode;
  final List<PositionEntry> positions;
  final String? timestamp;
  final String? decodeStrategy;
  final int driverCount;
  final double rawUpdatesPerSecond;
  final int? lastUpdateAgeMs;

  /// 응답 본문 바이트 수 — 모드별 전송량을 앱에서도 바로 본다.
  final int payloadBytes;

  /// 왕복 소요(ms).
  final int fetchMs;

  bool get hasPositions => positions.isNotEmpty;
}

/// 파싱/네트워크 실패까지 담는 결과. 예외를 던지지 않는다.
class PositionFetchResult {
  const PositionFetchResult({this.snapshot, this.error});

  final PositionSnapshot? snapshot;
  final String? error;

  bool get ok => snapshot != null;
}

/// Position 실험 endpoint 의 기본 주소.
///
/// 릴리스 기본값을 두지 않는다 — 이 화면은 디버그 빌드 전용이고, 실수로
/// 프로덕션 트래픽이 생기면 안 된다. 실기기 테스트는 dart-define 으로 주입한다:
///   flutter run --dart-define=POSITION_DEBUG_URL=http://192.168.0.10:8787/debug/position
const String kPositionDebugUrl = String.fromEnvironment(
  'POSITION_DEBUG_URL',
  defaultValue: 'http://localhost:8787/debug/position',
);

/// `/debug/position` 을 읽어 [PositionSnapshot] 으로 만든다.
class PositionDebugService {
  PositionDebugService({this.baseUrl = kPositionDebugUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  static const Duration timeout = Duration(seconds: 5);

  /// [mode] 의 최신 프레임을 가져온다. 실패해도 예외를 던지지 않는다.
  ///
  /// [includeMetrics] 가 false 면 `metrics=0` 으로 프레임만 받아, 실제 전송
  /// 구조에서의 페이로드 크기를 측정한다(측정값이 계측 필드로 부풀지 않게).
  Future<PositionFetchResult> fetch(
    PositionSamplingMode mode, {
    bool includeMetrics = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: <String, String>{
          'mode': mode.query,
          if (!includeMetrics) 'metrics': '0',
        },
      );
      final response = await httpClient.get(uri).timeout(timeout);
      stopwatch.stop();

      if (response.statusCode != 200) {
        return PositionFetchResult(
          error: 'HTTP ${response.statusCode} (${uri.host})',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const PositionFetchResult(error: '예상치 못한 응답 형식');
      }

      final rawPositions = decoded['positions'];
      final positions = <PositionEntry>[];
      if (rawPositions is List) {
        for (final raw in rawPositions) {
          final entry = PositionEntry.tryParse(raw);
          if (entry != null) positions.add(entry);
        }
      }

      final debug = decoded['debug'];
      final debugMap = debug is Map<String, dynamic>
          ? debug
          : const <String, dynamic>{};

      return PositionFetchResult(
        snapshot: PositionSnapshot(
          enabled: decoded['enabled'] == true,
          mock: decoded['mock'] == true,
          mode: decoded['mode'] is String
              ? decoded['mode'] as String
              : mode.query,
          positions: positions,
          timestamp: decoded['timestamp'] as String?,
          decodeStrategy: debugMap['decodeStrategy'] as String?,
          driverCount: debugMap['driverCount'] is num
              ? (debugMap['driverCount'] as num).toInt()
              : positions.length,
          rawUpdatesPerSecond: debugMap['rawUpdatesPerSecond'] is num
              ? (debugMap['rawUpdatesPerSecond'] as num).toDouble()
              : 0,
          lastUpdateAgeMs: debugMap['lastUpdateAgeMs'] is num
              ? (debugMap['lastUpdateAgeMs'] as num).toInt()
              : null,
          payloadBytes: response.bodyBytes.length,
          fetchMs: stopwatch.elapsedMilliseconds,
        ),
      );
    } catch (error) {
      return PositionFetchResult(error: error.toString());
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// 좌표 자동 맞춤용 경계 상자.
///
/// F1 position 좌표계는 서킷마다 원점·스케일이 달라서 고정 변환을 쓸 수 없다.
/// 관측된 좌표에서 경계를 누적해 화면에 맞춘다 — 차량이 그리는 궤적이 실제
/// 서킷 모양으로 보이는지가 곧 좌표 검증이다.
class PositionBounds {
  const PositionBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get width => (maxX - minX).abs();
  double get height => (maxY - minY).abs();
  bool get isValid => width > 0 && height > 0;

  /// 새 좌표들을 포함하도록 확장한 경계를 만든다.
  PositionBounds extend(Iterable<PositionEntry> entries) {
    var nextMinX = minX;
    var nextMaxX = maxX;
    var nextMinY = minY;
    var nextMaxY = maxY;
    for (final entry in entries) {
      if (entry.x < nextMinX) nextMinX = entry.x;
      if (entry.x > nextMaxX) nextMaxX = entry.x;
      if (entry.y < nextMinY) nextMinY = entry.y;
      if (entry.y > nextMaxY) nextMaxY = entry.y;
    }
    return PositionBounds(
      minX: nextMinX,
      maxX: nextMaxX,
      minY: nextMinY,
      maxY: nextMaxY,
    );
  }

  static PositionBounds? fromEntries(Iterable<PositionEntry> entries) {
    if (entries.isEmpty) return null;
    final first = entries.first;
    return PositionBounds(
      minX: first.x,
      maxX: first.x,
      minY: first.y,
      maxY: first.y,
    ).extend(entries);
  }
}

/// 두 프레임 사이를 [t](0~1)로 선형 보간한다.
///
/// 새 프레임에만 있는 차량은 그대로 두고, 이전 프레임에만 있는 차량은 버린다.
/// **외삽(extrapolation)은 하지 않는다** — 다음 프레임이 늦으면 마지막 위치에서
/// 멈추는 편이 안전하다(유령 차량이 트랙 밖으로 흘러가지 않는다).
List<PositionEntry> interpolatePositions(
  List<PositionEntry> from,
  List<PositionEntry> to,
  double t,
) {
  if (from.isEmpty) return to;
  if (to.isEmpty) return from;
  final clamped = t.clamp(0.0, 1.0);
  final previousByNumber = <String, PositionEntry>{
    for (final entry in from) entry.racingNumber: entry,
  };

  return <PositionEntry>[
    for (final target in to)
      if (previousByNumber[target.racingNumber] case final previous?)
        PositionEntry(
          racingNumber: target.racingNumber,
          x: previous.x + (target.x - previous.x) * clamped,
          y: previous.y + (target.y - previous.y) * clamped,
          z: target.z,
          status: target.status,
        )
      else
        target,
  ];
}
