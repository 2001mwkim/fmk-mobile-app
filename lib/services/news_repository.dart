import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/news_samples.dart';
import '../models/news_item.dart';

/// 소식 탭에 노출할 최대 항목 수.
const int kNewsDisplayLimit = 20;

/// 소식 데이터 공급 계층.
///
/// 앱은 외부 사이트를 직접 크롤링하지 않고, 서버가 수집·요약한 JSON 만 받는다.
/// 실서버 완성 시 이 인터페이스의 HTTP 구현
/// (예: `GET /api/news?limit=20&lang=ko` 를 [NewsItem.fromJson] 으로 파싱)으로
/// [SampleNewsRepository] 를 교체하면 화면 코드는 그대로 재사용된다.
abstract class NewsRepository {
  Future<List<NewsItem>> fetchLatest({int limit = kNewsDisplayLimit});
}

/// 뉴스 요청 타임아웃(라이브 폴링과 동일하게 화면 응답성 우선).
const Duration kNewsFetchTimeout = Duration(seconds: 8);

/// 서버 API 구현 초안. 계약은 docs/news_api_contract.md 참고.
///
/// `GET {baseUrl}/api/news?limit=20&lang=ko` 를 호출해 [NewsItem.fromJson]
/// 으로 파싱한다. live_session_service 와 같은 원칙:
/// - 깨진 항목은 그 항목만 건너뛴다(전체 실패 아님)
/// - 네트워크 오류/타임아웃/비정상 JSON 은 예외를 던지지 않고 빈 목록을
///   돌려줘 화면이 죽지 않게 한다(NewsScreen 이 빈 상태 카드를 보여준다)
///
/// 실서버가 준비되면 NewsScreen 의 기본 저장소를 이 클래스로 교체한다.
/// 그 전까지 앱 기본값은 [SampleNewsRepository] 다.
class HttpNewsRepository implements NewsRepository {
  const HttpNewsRepository({required this.baseUrl, this.client});

  /// 서버 origin (예: 'https://news.example.com'). 경로는 붙이지 않는다.
  final String baseUrl;

  /// 테스트 주입용 클라이언트(없으면 매 요청마다 생성/정리).
  final http.Client? client;

  @override
  Future<List<NewsItem>> fetchLatest({int limit = kNewsDisplayLimit}) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(baseUrl).replace(
        path: '/api/news',
        queryParameters: {'limit': '$limit', 'lang': 'ko'},
      );
      final response = await httpClient.get(uri).timeout(kNewsFetchTimeout);
      if (response.statusCode != 200) return const [];
      // JSON 은 스펙상 UTF-8 (RFC 8259). 서버가 charset 헤더를 생략하면
      // response.body 가 latin1 로 잘못 디코딩돼 한글 브리핑이 깨지므로
      // bodyBytes 를 UTF-8 로 직접 디코딩한다.
      return parseNewsJson(utf8.decode(response.bodyBytes), limit: limit);
    } catch (_) {
      // 네트워크/타임아웃/파싱 오류 → 빈 목록(빈 상태 UI 표시).
      return const [];
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// 뉴스 응답 본문 파싱. `{ "items": [...] }` 래퍼가 표준이지만
/// 루트 배열도 허용한다(계약 문서의 하위 호환 규칙).
/// 깨진 항목은 건너뛰고, 최신순 정렬 후 [limit] 개까지만 돌려준다.
List<NewsItem> parseNewsJson(String body, {int limit = kNewsDisplayLimit}) {
  try {
    final decoded = jsonDecode(body);
    final rawItems = decoded is Map ? decoded['items'] : decoded;
    if (rawItems is! List) return const [];

    final items = <NewsItem>[];
    for (final raw in rawItems) {
      if (items.length >= limit) break;
      if (raw is! Map) continue;
      final item = NewsItem.fromJson(raw.cast<String, dynamic>());
      if (item != null) items.add(item);
    }

    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items;
  } catch (_) {
    return const [];
  }
}

/// 서버 API 완성 전까지 쓰는 로컬 샘플 구현.
class SampleNewsRepository implements NewsRepository {
  const SampleNewsRepository({this.now});

  /// 테스트/데모용 기준 시각(없으면 현재 시각).
  final DateTime? now;

  @override
  Future<List<NewsItem>> fetchLatest({int limit = kNewsDisplayLimit}) async {
    final items = buildSampleNewsItems(now)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return items.take(limit).toList();
  }
}
