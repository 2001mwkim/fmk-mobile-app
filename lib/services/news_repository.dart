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
