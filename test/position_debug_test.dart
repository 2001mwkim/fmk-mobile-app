import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fmk_app/services/position_debug_service.dart';

// Position.z 실험(2026-09 POC) 앱 측 로직 테스트.
//
// 실제 F1 좌표가 정상인지는 여기서 검증할 수 없다(세션에서만 가능). 여기서
// 확인하는 것은 응답 파싱·보간·좌표 맞춤이 규칙대로 동작하는가이다.

Map<String, dynamic> responseBody({
  bool enabled = true,
  bool mock = false,
  String mode = '1hz',
  List<Map<String, dynamic>>? positions,
}) {
  return <String, dynamic>{
    'enabled': enabled,
    'mock': mock,
    'mode': mode,
    'timestamp': '2026-09-25T12:00:00.000Z',
    'positions':
        positions ??
        <Map<String, dynamic>>[
          {
            'racingNumber': '1',
            'x': 100,
            'y': -200,
            'z': 5,
            'status': 'OnTrack',
          },
          {'racingNumber': '16', 'x': 300, 'y': 400, 'z': null, 'status': null},
        ],
    'debug': {
      'sourceTimestamp': '2026-09-25T12:00:00.000Z',
      'collectorReceivedAt': '2026-09-25T12:00:00.100Z',
      'driverCount': 2,
      'rawUpdatesPerSecond': 3.9,
      'lastUpdateAgeMs': 120,
      'decodeStrategy': 'base64+inflateRaw',
    },
  };
}

/// collector `/debug/position?mode=2hz&metrics=0` 의 **실제 응답**을 그대로 붙인
/// 것이다(2026-09-25, 합성 피더로 구동). 손으로 쓴 가정이 아니라 서버가 실제로
/// 내보낸 바이트라서, 서버/앱 계약이 어긋나면 이 테스트가 먼저 깨진다.
/// 차량 20대 중 5대만 남겨 가독성을 확보했고 형식은 원본 그대로다.
const String kCapturedCollectorResponse =
    '{"enabled": true, "mock": true, "mode": "2hz", '
    '"timestamp": "2026-09-25T07:52:57.286Z", "positions": ['
    '{"racingNumber": "1", "x": -7903, "y": -807, "z": 37, "status": "OnTrack"}, '
    '{"racingNumber": "4", "x": -7938, "y": 644, "z": -30, "status": "OnTrack"}, '
    '{"racingNumber": "5", "x": -7355, "y": 2045, "z": -87, "status": "OnTrack"}, '
    '{"racingNumber": "6", "x": -6199, "y": 3287, "z": -118, "status": "OnTrack"}, '
    '{"racingNumber": "10", "x": -4560, "y": 4272, "z": -112, "status": "OnTrack"}'
    '], "debug": {"sourceTimestamp": "2026-09-25T07:52:57.286Z", '
    '"collectorReceivedAt": "2026-09-25T07:52:57.544Z", '
    '"servedAt": "2026-09-25T07:52:57.744Z", "driverCount": 20, '
    '"rawUpdatesPerSecond": 3.644, "lastUpdateAgeMs": 200, '
    '"decodeStrategy": "base64+inflateRaw", "buildMs": 0.294}}';

void main() {
  group('실제 collector 응답 계약', () {
    test('캡처한 서버 응답을 그대로 파싱한다', () async {
      final service = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient(
          (_) async => http.Response(kCapturedCollectorResponse, 200),
        ),
      );

      final result = await service.fetch(PositionSamplingMode.hz2);
      expect(result.ok, isTrue);
      final snapshot = result.snapshot!;
      expect(snapshot.enabled, isTrue);
      // 합성 피더 데이터는 반드시 mock 으로 구분돼야 한다.
      expect(snapshot.mock, isTrue);
      expect(snapshot.mode, '2hz');
      expect(snapshot.positions.length, 5);
      expect(snapshot.decodeStrategy, 'base64+inflateRaw');
      // driverCount 는 서버가 센 전체 대수(축약 전 20대).
      expect(snapshot.driverCount, 20);
      expect(snapshot.rawUpdatesPerSecond, closeTo(3.644, 0.001));
      expect(snapshot.lastUpdateAgeMs, 200);

      // 좌표가 음수/양수 모두 정상 파싱되는지 — 좌표계 부호 처리 확인.
      final first = snapshot.positions.first;
      expect(first.racingNumber, '1');
      expect(first.x, -7903);
      expect(first.y, -807);
      expect(first.z, 37);
      expect(first.status, 'OnTrack');

      // 경계 계산이 실제 좌표 범위에서 성립하는지.
      final bounds = PositionBounds.fromEntries(snapshot.positions)!;
      expect(bounds.minX, -7938);
      expect(bounds.maxX, -4560);
      expect(bounds.minY, -807);
      expect(bounds.maxY, 4272);
      expect(bounds.isValid, isTrue);
    });
  });

  group('PositionDebugService', () {
    test('정상 응답을 파싱한다', () async {
      final service = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient((request) async {
          expect(request.url.queryParameters['mode'], '1hz');
          return http.Response(jsonEncode(responseBody()), 200);
        }),
      );

      final result = await service.fetch(PositionSamplingMode.hz1);
      expect(result.ok, isTrue);
      final snapshot = result.snapshot!;
      expect(snapshot.enabled, isTrue);
      expect(snapshot.mock, isFalse);
      expect(snapshot.positions.length, 2);
      expect(snapshot.positions.first.racingNumber, '1');
      expect(snapshot.positions.first.x, 100);
      expect(snapshot.positions.first.y, -200);
      expect(snapshot.positions.first.z, 5);
      expect(snapshot.positions[1].z, isNull);
      expect(snapshot.decodeStrategy, 'base64+inflateRaw');
      expect(snapshot.driverCount, 2);
      expect(snapshot.payloadBytes, greaterThan(0));
    });

    test('metrics=0 을 요청하면 쿼리에 포함된다', () async {
      var sawMetricsParam = false;
      final service = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient((request) async {
          sawMetricsParam = request.url.queryParameters['metrics'] == '0';
          return http.Response(jsonEncode(responseBody()), 200);
        }),
      );

      await service.fetch(PositionSamplingMode.raw, includeMetrics: false);
      expect(sawMetricsParam, isTrue);
    });

    test('실험이 꺼져 있으면 enabled=false 로 파싱된다', () async {
      final service = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              responseBody(enabled: false, positions: <Map<String, dynamic>>[]),
            ),
            200,
          ),
        ),
      );

      final result = await service.fetch(PositionSamplingMode.raw);
      expect(result.ok, isTrue);
      expect(result.snapshot!.enabled, isFalse);
      expect(result.snapshot!.hasPositions, isFalse);
    });

    test('HTTP 오류와 잘못된 본문에서 예외를 던지지 않는다', () async {
      final errorService = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      final errorResult = await errorService.fetch(PositionSamplingMode.raw);
      expect(errorResult.ok, isFalse);
      expect(errorResult.error, contains('503'));

      final malformedService = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      final malformedResult = await malformedService.fetch(
        PositionSamplingMode.raw,
      );
      expect(malformedResult.ok, isFalse);
    });

    test('좌표가 없는 엔트리는 건너뛴다', () async {
      final service = PositionDebugService(
        baseUrl: 'http://localhost:8787/debug/position',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(
              responseBody(
                positions: <Map<String, dynamic>>[
                  {'racingNumber': '1', 'x': 1, 'y': 2},
                  {'racingNumber': '2'},
                  {'x': 5, 'y': 6},
                ],
              ),
            ),
            200,
          ),
        ),
      );

      final result = await service.fetch(PositionSamplingMode.raw);
      expect(result.snapshot!.positions.length, 1);
      expect(result.snapshot!.positions.single.racingNumber, '1');
    });
  });

  group('보간', () {
    const from = <PositionEntry>[
      PositionEntry(racingNumber: '1', x: 0, y: 0),
      PositionEntry(racingNumber: '2', x: 10, y: 10),
    ];
    const to = <PositionEntry>[
      PositionEntry(racingNumber: '1', x: 100, y: 200),
      PositionEntry(racingNumber: '2', x: 20, y: 30),
    ];

    test('중간 지점을 계산한다', () {
      final mid = interpolatePositions(from, to, 0.5);
      expect(mid.first.x, 50);
      expect(mid.first.y, 100);
      expect(mid[1].x, 15);
      expect(mid[1].y, 20);
    });

    test('t 는 0~1 로 제한된다 — 외삽하지 않는다', () {
      final overshoot = interpolatePositions(from, to, 2.5);
      expect(overshoot.first.x, 100);
      expect(overshoot.first.y, 200);

      final undershoot = interpolatePositions(from, to, -1);
      expect(undershoot.first.x, 0);
    });

    test('새로 등장한 차량은 목표 위치를 그대로 쓴다', () {
      final result = interpolatePositions(
        const <PositionEntry>[PositionEntry(racingNumber: '1', x: 0, y: 0)],
        const <PositionEntry>[
          PositionEntry(racingNumber: '1', x: 10, y: 0),
          PositionEntry(racingNumber: '99', x: 500, y: 500),
        ],
        0.5,
      );
      expect(result.length, 2);
      expect(result.first.x, 5);
      expect(result[1].x, 500);
    });

    test('한쪽이 비면 다른 쪽을 그대로 돌려준다', () {
      expect(interpolatePositions(const <PositionEntry>[], to, 0.5), to);
      expect(interpolatePositions(from, const <PositionEntry>[], 0.5), from);
    });
  });

  group('좌표 자동 맞춤', () {
    test('엔트리들로 경계를 만든다', () {
      final bounds = PositionBounds.fromEntries(const <PositionEntry>[
        PositionEntry(racingNumber: '1', x: -100, y: -50),
        PositionEntry(racingNumber: '2', x: 300, y: 250),
      ]);
      expect(bounds, isNotNull);
      expect(bounds!.minX, -100);
      expect(bounds.maxX, 300);
      expect(bounds.width, 400);
      expect(bounds.height, 300);
      expect(bounds.isValid, isTrue);
    });

    test('새 좌표로 경계를 넓힌다', () {
      final bounds = PositionBounds.fromEntries(const <PositionEntry>[
        PositionEntry(racingNumber: '1', x: 0, y: 0),
      ])!.extend(const <PositionEntry>[
        PositionEntry(racingNumber: '2', x: -500, y: 900),
      ]);
      expect(bounds.minX, -500);
      expect(bounds.maxY, 900);
    });

    test('빈 목록이면 경계가 없다', () {
      expect(PositionBounds.fromEntries(const <PositionEntry>[]), isNull);
    });
  });

  group('샘플링 모드', () {
    test('쿼리 문자열이 서버 계약과 일치한다', () {
      expect(PositionSamplingMode.raw.query, 'raw');
      expect(PositionSamplingMode.hz5.query, '5hz');
      expect(PositionSamplingMode.hz2.query, '2hz');
      expect(PositionSamplingMode.hz1.query, '1hz');
    });

    test('모드별 기대 간격', () {
      expect(PositionSamplingMode.hz1.expectedInterval.inMilliseconds, 1000);
      expect(PositionSamplingMode.hz2.expectedInterval.inMilliseconds, 500);
      expect(PositionSamplingMode.hz5.expectedInterval.inMilliseconds, 200);
    });
  });
}
