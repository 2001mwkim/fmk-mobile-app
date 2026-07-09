import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/services/news_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Map<String, dynamic> validItem(String id) {
    return {
      'id': id,
      'sourceName': 'Motorsport.com',
      'originalTitle': 'Headline $id',
      'titleKo': '$id 한국어 제목',
      'originalLink': 'https://www.motorsport.com/$id',
      'publishedAt': '2026-07-07T0${id.hashCode % 10}:00:00.000Z',
      'fetchedAt': '2026-07-07T09:10:00.000Z',
      'aiBriefKo': '$id 한국어 브리핑입니다.',
      'tags': ['페라리'],
      'hash': 'hash-$id',
    };
  }

  http.Response jsonResponse(Object data) {
    // 한글 본문이 있어 latin1 기본 인코딩 대신 UTF-8 바이트로 응답을 만든다.
    return http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  HttpNewsRepository repositoryWith(MockClient client) {
    return HttpNewsRepository(
      baseUrl: 'https://news.example.com',
      client: client,
    );
  }

  test('default base url points to production Vercel domain', () {
    // dev/prod 분리는 --dart-define=NEWS_API_BASE_URL 로만 한다(한 곳 관리).
    expect(kNewsApiBaseUrl, 'https://www.formulamagazine.kr');
  });

  test('parses items wrapper into NewsItem list', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return jsonResponse({
        'generatedAt': '2026-07-07T10:00:00.000Z',
        'items': [validItem('a'), validItem('b')],
      });
    });

    final items = await repositoryWith(client).fetchLatest();

    expect(items.length, 2);
    expect(items.map((i) => i.id), containsAll(['a', 'b']));
    expect(items.first.sourceName, 'Motorsport.com');
    expect(items.first.titleKo, isNotEmpty); // 서버 titleKo 파싱
    // 요청 형태: /api/news?limit=20&lang=ko
    expect(requested.path, '/api/news');
    expect(requested.queryParameters['limit'], '$kNewsDisplayLimit');
    expect(requested.queryParameters['lang'], 'ko');
  });

  test('titleKo 가 없는 구버전 응답도 정상 파싱된다 (하위 호환)', () async {
    final legacy = validItem('legacy')..remove('titleKo');
    final client = MockClient((request) async {
      return jsonResponse({
        'items': [legacy],
      });
    });

    final items = await repositoryWith(client).fetchLatest();

    expect(items.single.id, 'legacy');
    expect(items.single.titleKo, ''); // 빈 값 → 앱이 제목 영역 생략
    expect(items.single.originalTitle, 'Headline legacy'); // 내부 보존
  });

  test('skips broken items but keeps valid ones', () async {
    final client = MockClient((request) async {
      return jsonResponse({
        'items': [
          validItem('ok-1'),
          // 필수 필드 누락(aiBriefKo 없음) → 이 항목만 skip
          {
            'id': 'broken',
            'sourceName': 'Autosport',
            'originalTitle': 'Broken',
            'originalLink': 'https://example.com',
            'publishedAt': '2026-07-07T00:00:00.000Z',
          },
          // 타입 자체가 잘못된 항목
          'not-a-map',
          validItem('ok-2'),
        ],
      });
    });

    final items = await repositoryWith(client).fetchLatest();

    expect(items.length, 2);
    expect(items.map((i) => i.id), containsAll(['ok-1', 'ok-2']));
  });

  test('caps oversized responses to requested limit', () async {
    final client = MockClient((request) async {
      return jsonResponse({
        'items': [for (var i = 0; i < 60; i++) validItem('n$i')],
      });
    });

    final items = await repositoryWith(client).fetchLatest();

    expect(items.length, kNewsDisplayLimit);
  });

  test(
    'returns empty list on network failure, HTTP error, and bad JSON',
    () async {
      final failing = MockClient((request) async {
        throw http.ClientException('connection refused');
      });
      expect(await repositoryWith(failing).fetchLatest(), isEmpty);

      final serverError = MockClient((request) async {
        return http.Response('oops', 500);
      });
      expect(await repositoryWith(serverError).fetchLatest(), isEmpty);

      final badJson = MockClient((request) async {
        return http.Response('not json at all', 200);
      });
      expect(await repositoryWith(badJson).fetchLatest(), isEmpty);

      // 루트 배열(래퍼 없는 하위 호환 형태)은 정상 파싱된다.
      final bareArray = MockClient((request) async {
        return jsonResponse([validItem('bare')]);
      });
      expect((await repositoryWith(bareArray).fetchLatest()).single.id, 'bare');
    },
  );
}
