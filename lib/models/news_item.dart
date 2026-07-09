/// AI 한국어 브리핑 뉴스 항목.
///
/// 앱은 외부 뉴스 사이트를 직접 크롤링하지 않는다 — 서버가 수집·요약해
/// 내려주는 정리된 JSON(추후 `/api/news?limit=20&lang=ko`)만 표시한다.
/// 원문 전문은 저장/표시하지 않고 2~3줄 브리핑과 원문 링크만 제공한다.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.sourceName,
    required this.originalTitle,
    this.titleKo = '',
    required this.originalLink,
    required this.publishedAt,
    required this.fetchedAt,
    this.sourceSummary,
    required this.aiBriefKo,
    this.tags = const [],
    required this.hash,
  });

  final String id;

  /// 출처 매체명(예: 'Motorsport.com'). 카드에 항상 노출한다(출처 명시 정책).
  final String sourceName;

  /// 원문 제목(원어). 내부 보존/원문 확인용 — **UI 에 직접 표시하지 않는다**.
  final String originalTitle;

  /// 앱 카드에 표시할 한국어 제목(서버 AI 생성). 빈 값이면 제목 영역을
  /// 생략한다 — 영어 원문 제목으로 대체하지 않는다(하위 호환: 구버전 응답).
  final String titleKo;

  /// 원문 기사 링크. '원문 보기'로 항상 제공한다.
  final String originalLink;
  final DateTime publishedAt;
  final DateTime fetchedAt;

  /// RSS 등 출처가 제공한 요약(있을 때만).
  final String? sourceSummary;

  /// 서버가 생성한 2~3줄 한국어 브리핑.
  final String aiBriefKo;

  /// 드라이버/팀/그랑프리 태그(예: '해밀턴', '페라리', '영국 GP').
  final List<String> tags;

  /// 중복 수집 방지용 해시(서버 생성).
  final String hash;

  /// 서버 JSON 파싱. live.json 파서와 같은 원칙으로 방어적으로 처리하고,
  /// 필수 필드가 깨져 있으면 null 을 반환한다(항목 단위 skip).
  static NewsItem? fromJson(Map<String, dynamic> json) {
    final id = _string(json['id']);
    final sourceName = _string(json['sourceName']);
    final originalTitle = _string(json['originalTitle']);
    final originalLink = _string(json['originalLink']);
    final publishedAt = _dateTime(json['publishedAt']);
    final aiBriefKo = _string(json['aiBriefKo']);
    if (id == null ||
        sourceName == null ||
        originalTitle == null ||
        originalLink == null ||
        publishedAt == null ||
        aiBriefKo == null) {
      return null;
    }

    return NewsItem(
      id: id,
      sourceName: sourceName,
      originalTitle: originalTitle,
      // 선택 필드 — 없거나 빈 구버전 응답도 유효(하위 호환).
      titleKo: _string(json['titleKo']) ?? '',
      originalLink: originalLink,
      publishedAt: publishedAt,
      fetchedAt: _dateTime(json['fetchedAt']) ?? publishedAt,
      sourceSummary: _string(json['sourceSummary']),
      aiBriefKo: aiBriefKo,
      tags: json['tags'] is List
          ? (json['tags'] as List).whereType<String>().toList()
          : const [],
      hash: _string(json['hash']) ?? id,
    );
  }

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }
}
