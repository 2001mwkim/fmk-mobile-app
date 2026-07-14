import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/news_item.dart';
import 'package:fmk_app/screens/news_screen.dart';
import 'package:fmk_app/services/news_repository.dart';
import 'package:fmk_app/theme/app_theme.dart';

void main() {
  final now = DateTime.parse('2026-07-07T12:00:00+09:00');

  NewsItem item({
    required String id,
    required DateTime publishedAt,
    String titleKo = '',
    List<String> tags = const [],
    String? thumbnailUrl,
    List<String> relatedSources = const [],
  }) {
    return NewsItem(
      id: id,
      sourceName: 'Motorsport.com',
      originalTitle: 'Test headline $id',
      titleKo: titleKo,
      originalLink: 'https://www.motorsport.com/$id',
      publishedAt: publishedAt,
      fetchedAt: publishedAt,
      aiBriefKo: '$id 한국어 브리핑 본문입니다.',
      tags: tags,
      hash: 'hash-$id',
      thumbnailUrl: thumbnailUrl,
      relatedSources: relatedSources,
    );
  }

  testWidgets('news screen renders header and repository items', (
    tester,
  ) async {
    final repository = _FakeNewsRepository([
      item(
        id: 'a',
        publishedAt: now.subtract(const Duration(hours: 2)),
        titleKo: 'a번 한국어 제목입니다',
        tags: const ['해밀턴', '페라리'],
        // 유사 기사로 묶인 출처 — "외 1곳" 표시 검증
        relatedSources: const ['Autosport'],
      ),
      item(id: 'b', publishedAt: now.subtract(const Duration(days: 1))),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: NewsScreen(repository: repository, nowOverride: now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('소식'), findsOneWidget);
    expect(find.text('해외 F1 주요 소식을 한국어 브리핑으로 빠르게 확인하세요.'), findsOneWidget);
    // 출처 · 상대 시간 · 한국어 제목 · 브리핑 · 원문 보기
    // 묶인 기사(a)는 "외 1곳", 단독 기사(b)는 출처명 그대로.
    expect(find.text('Motorsport.com 외 1곳'), findsOneWidget);
    expect(find.text('Motorsport.com'), findsOneWidget);
    expect(find.textContaining('2시간 전'), findsOneWidget);
    expect(find.text('a번 한국어 제목입니다'), findsOneWidget);
    expect(find.text('a 한국어 브리핑 본문입니다.'), findsOneWidget);
    // 태그 칩은 UI 에서 제거됨(데이터는 향후 필터/검색용으로 유지) —
    // tags 를 넣어도 화면에 표시되지 않는다.
    expect(find.text('해밀턴'), findsNothing);
    expect(find.text('페라리'), findsNothing);
    expect(find.text('원문 보기'), findsNWidgets(2));
    // 영어 원문 제목은 어떤 카드에서도 표시하지 않는다.
    expect(find.text('Test headline a'), findsNothing);
    expect(find.text('Test headline b'), findsNothing);
  });

  testWidgets('titleKo 가 없으면 영어 제목 대신 제목 영역을 생략한다', (tester) async {
    final repository = _FakeNewsRepository([
      // titleKo 없음(구버전 응답/AI 미생성) — 브리핑만 표시돼야 한다
      item(id: 'old', publishedAt: now.subtract(const Duration(hours: 1))),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: NewsScreen(repository: repository, nowOverride: now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test headline old'), findsNothing); // 영어 fallback 금지
    expect(find.text('old 한국어 브리핑 본문입니다.'), findsOneWidget);
    expect(find.text('원문 보기'), findsOneWidget); // 원문 접근은 링크로 유지
  });

  testWidgets('thumbnailUrl 이 있는 카드만 썸네일 이미지를 렌더링한다', (tester) async {
    final repository = _FakeNewsRepository([
      item(
        id: 'pic',
        publishedAt: now.subtract(const Duration(hours: 1)),
        titleKo: '썸네일 있는 소식',
        thumbnailUrl: 'https://cdn.example.com/pic.jpg',
      ),
      item(
        id: 'nopic',
        publishedAt: now.subtract(const Duration(hours: 2)),
        titleKo: '썸네일 없는 소식',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: NewsScreen(repository: repository, nowOverride: now),
      ),
    );
    await tester.pumpAndSettle();

    // 카드 2장 중 썸네일이 있는 1장만 Image 위젯을 가진다.
    // (테스트 환경은 네트워크가 차단돼 errorBuilder 의 placeholder 가 뜨지만
    // 크래시 없이 렌더링되는 것까지가 검증 대상)
    expect(find.byType(Image), findsOneWidget);
    // 썸네일이 있어도 제목/요약/원문 보기가 정상 렌더링된다.
    expect(find.text('썸네일 있는 소식'), findsOneWidget);
    expect(find.text('pic 한국어 브리핑 본문입니다.'), findsOneWidget);
    expect(find.text('썸네일 없는 소식'), findsOneWidget);
    expect(find.text('원문 보기'), findsNWidgets(2));
  });

  testWidgets('news screen caps list to display limit', (tester) async {
    final repository = _FakeNewsRepository([
      for (var i = 0; i < 30; i++)
        item(
          id: 'n$i',
          publishedAt: now.subtract(Duration(hours: i + 1)),
        ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: NewsScreen(repository: repository, nowOverride: now),
      ),
    );
    await tester.pumpAndSettle();

    // repository 호출이 limit=20 으로 이뤄져 최신 20개만 노출된다.
    expect(repository.lastLimit, kNewsDisplayLimit);
  });

  test('relative time formats Korean labels', () {
    expect(
      newsRelativeTimeKo(now.subtract(const Duration(seconds: 30)), now),
      '방금 전',
    );
    expect(
      newsRelativeTimeKo(now.subtract(const Duration(minutes: 5)), now),
      '5분 전',
    );
    expect(
      newsRelativeTimeKo(now.subtract(const Duration(hours: 2)), now),
      '2시간 전',
    );
    expect(
      newsRelativeTimeKo(now.subtract(const Duration(days: 3)), now),
      '3일 전',
    );
    expect(
      newsRelativeTimeKo(now.subtract(const Duration(days: 10)), now),
      '6.27',
    );
  });

  test('sample repository returns at most 20 sorted items', () async {
    final items = await SampleNewsRepository(now: now).fetchLatest();

    expect(items.length, lessThanOrEqualTo(kNewsDisplayLimit));
    for (var i = 1; i < items.length; i++) {
      expect(
        items[i - 1].publishedAt.isAfter(items[i].publishedAt) ||
            items[i - 1].publishedAt.isAtSameMomentAs(items[i].publishedAt),
        isTrue,
      );
    }
  });
}

class _FakeNewsRepository implements NewsRepository {
  _FakeNewsRepository(this.items);

  final List<NewsItem> items;
  int? lastLimit;

  @override
  Future<List<NewsItem>> fetchLatest({int limit = kNewsDisplayLimit}) async {
    lastLimit = limit;
    return items.take(limit).toList();
  }
}
