import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/live_session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// collector 응답 최소 형태(라이브 센터가 쓰는 필드만).
String _body({String raceName = 'Dutch Grand Prix'}) => jsonEncode({
  'snapshot': {
    'status': 'ended',
    'updatedAt': '2026-08-23T14:00:00Z',
    'raceId': 'netherlands-2026',
    'raceName': raceName,
    'sessionType': 'Race',
    'sessionName': 'Race',
    'classification': [
      {'position': 1, 'code': 'NOR', 'displayName': '랜도 노리스'},
    ],
  },
});

const String _primary = 'https://live.example.test/live.json';
const String _fallback = 'https://www.example.test/api/live';

/// 요청이 실제로 어느 host 로 갔는지 순서대로 기록하는 클라이언트.
MockClient _client({
  required Set<String> healthy,
  required List<String> log,
  Map<String, String> headers = const {'content-type': 'application/json'},
}) {
  return MockClient((request) async {
    final url = request.url.toString();
    log.add(url);
    if (!healthy.contains(url)) {
      // DNS 실패(NXDOMAIN)와 같은 계층의 오류 — 응답 자체가 없다.
      throw http.ClientException('lookup failed');
    }
    return http.Response.bytes(utf8.encode(_body()), 200, headers: headers);
  });
}

void main() {
  test('1순위가 살아 있으면 폴백을 건드리지 않는다', () async {
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: _client(healthy: {_primary, _fallback}, log: log),
    );

    final result = await service.fetchResult();

    expect(result.succeeded, isTrue);
    expect(result.snapshot?.raceName, 'Dutch Grand Prix');
    expect(log, [_primary]);
  });

  test('1순위가 죽으면 폴백으로 살아난다', () async {
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: _client(healthy: {_fallback}, log: log),
    );

    final result = await service.fetchResult();

    expect(result.succeeded, isTrue);
    expect(result.snapshot?.classification.first.code, 'NOR');
    expect(log, [_primary, _fallback]);
  });

  test('성공한 endpoint 를 기억해 다음 폴링의 1순위로 쓴다', () async {
    // DNS 장애가 이어지는 동안 매번 죽은 호스트부터 찌르면 폴링마다 타임아웃을 먹는다.
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: _client(healthy: {_fallback}, log: log),
    );

    await service.fetchResult();
    log.clear();
    await service.fetchResult();

    expect(log, [_fallback]);
    expect(service.activeUrl, _fallback);
  });

  test('1순위가 살아나면 별도 복구 로직 없이 되돌아간다', () async {
    // Vercel 폴백은 엣지 요청 비용을 쓰므로 상시 경로로 굳으면 안 된다.
    final log = <String>[];
    final healthy = <String>{_fallback};
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: _client(healthy: healthy, log: log),
    );

    await service.fetchResult();
    expect(service.activeUrl, _fallback);

    healthy.add(_primary); // DNS 정상화
    log.clear();
    await service.fetchResult(); // 폴백 성공 → 아직 폴백 유지
    await service.fetchResult();

    // 폴백이 1순위인 동안에도 실패 시 primary 를 다시 시도하므로,
    // primary 가 살아나면 그 시점에 1순위로 복귀한다.
    healthy.remove(_fallback);
    await service.fetchResult();
    expect(service.activeUrl, _primary);
  });

  test('모든 endpoint 가 죽으면 실패로 보고한다', () async {
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: _client(healthy: const {}, log: log),
    );

    final result = await service.fetchResult();

    expect(result.succeeded, isFalse);
    expect(result.snapshot, isNull);
    expect(log, [_primary, _fallback]);
  });

  test('HTTP 오류도 폴백 대상이다', () async {
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: MockClient((request) async {
        final url = request.url.toString();
        log.add(url);
        if (url == _primary) return http.Response('gateway error', 502);
        return http.Response.bytes(utf8.encode(_body()), 200);
      }),
    );

    final result = await service.fetchResult();

    expect(result.succeeded, isTrue);
    expect(log, [_primary, _fallback]);
  });

  test('응답은 왔지만 표시할 세션이 없으면 폴백하지 않는다', () async {
    // 정상 응답이다 — 폴백으로 넘어가면 Vercel 요청만 낭비한다.
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: _fallback,
      client: MockClient((request) async {
        log.add(request.url.toString());
        return http.Response('{"snapshot":null}', 200);
      }),
    );

    final result = await service.fetchResult();

    // 세션이 비었는지 판정은 컨트롤러(_isSessionSnapshot)의 몫이고, 여기서
    // 중요한 건 "정상 응답이므로 폴백을 안 탄다"는 것뿐이다.
    expect(result.succeeded, isTrue);
    expect(log, [_primary]);
  });

  test('charset 없는 application/json 응답도 한글이 깨지지 않는다', () async {
    // Vercel `/api/live` 는 charset 을 안 붙인다 — http 패키지의 body 는 그 경우
    // latin1 로 풀어서 드라이버 한글 이름이 깨진다.
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: '',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(_body()),
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );

    final result = await service.fetchResult();

    expect(result.snapshot?.classification.first.displayName, '랜도 노리스');
  });

  test('폴백 URL 이 비면 1순위만 시도한다', () async {
    final log = <String>[];
    final service = LiveSessionService(
      url: _primary,
      fallbackUrl: '',
      client: _client(healthy: const {}, log: log),
    );

    await service.fetchResult();

    expect(log, [_primary]);
  });

  test('릴리스 기본값은 Cloudflare 1순위 + Vercel 폴백이다', () {
    // 두 상수가 같은 호스트로 수렴하면 폴백이 무력화된다(회귀 방지).
    expect(kLiveJsonFallbackUrl, isNot(equals(kLiveJsonUrl)));
  }, skip: !const bool.fromEnvironment('dart.vm.product'));

  test('스냅샷 파싱은 endpoint 와 무관하게 동일하다', () async {
    for (final url in [_primary, _fallback]) {
      final service = LiveSessionService(
        url: url,
        fallbackUrl: '',
        client: _client(healthy: {url}, log: []),
      );
      final snapshot = await service.fetch();
      expect(snapshot, isA<LiveSessionSnapshot>());
      expect(snapshot?.status, LiveSessionStatus.ended);
    }
  });
}
