import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../services/news_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

/// 소식 탭 — AI 가 정리한 해외 F1 주요 소식(한국어 브리핑) 화면.
///
/// 데이터는 [NewsRepository] 계층에서 받아 렌더링만 한다(하드코딩 금지).
/// 기본값은 실서버 [HttpNewsRepository](`/api/news?limit=20&lang=ko`,
/// origin 은 kNewsApiBaseUrl 한 곳에서 관리). 서버 실패/빈 응답이면
/// 빈 상태 카드를 보여준다 — 샘플 데이터로 자동 폴백하지 않는다.
/// 정책: 앱은 직접 크롤링하지 않고 서버 JSON 만 렌더링,
/// 원문 전문 없이 2~3줄 브리핑 + 출처/원문 링크만 제공.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, this.repository, this.nowOverride});

  /// 테스트/개발용 주입 지점(예: [SampleNewsRepository]).
  final NewsRepository? repository;
  final DateTime? nowOverride;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final NewsRepository _repository =
      widget.repository ?? const HttpNewsRepository(baseUrl: kNewsApiBaseUrl);
  late final Future<List<NewsItem>> _future = _repository.fetchLatest();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<NewsItem>>(
          future: _future,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <NewsItem>[];
            final now = widget.nowOverride ?? DateTime.now();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _NewsHeader(),
                const SizedBox(height: 14),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.red),
                    ),
                  )
                else if (items.isEmpty)
                  const _NewsEmptyCard()
                else
                  for (final item in items) ...[
                    _NewsCard(item: item, now: now),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'F1 NEWS BRIEFING',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '소식',
            style: TextStyle(
              fontSize: 26,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '해외 F1 주요 소식을 한국어 브리핑으로 빠르게 확인하세요.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.heroSub,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.now});

  final NewsItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      onTap: () => _openOriginal(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 출처 · 발행 시간 (출처 명시 정책). 유사 기사가 묶인 경우
          // "Motorsport.com 외 1곳"처럼 함께 보도한 출처 수를 표시한다.
          Row(
            children: [
              Flexible(
                child: Text(
                  item.relatedSources.isEmpty
                      ? item.sourceName
                      : '${item.sourceName} 외 ${item.relatedSources.length}곳',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Pretendard',
                    color: AppColors.redSoft,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                ' · ${newsRelativeTimeKo(item.publishedAt, now)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 본문(제목+브리핑) 왼쪽 + 썸네일 오른쪽. 썸네일은 출처가 RSS 로
          // 직접 제공한 이미지만 서버가 내려준다(크롤링 금지 정책).
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목은 한국어(titleKo)만 표시한다. 빈 값이면(AI 미생성/
                    // 구버전 응답) 영어 원문 제목으로 대체하지 않고 제목 영역을
                    // 생략 — 브리핑이 본문 역할을 한다.
                    // 타이포: 뉴스 피드 톤 — 제목은 촘촘하게(height 1.18),
                    // 요약은 태그 제거로 확보된 공간을 써서 더 크고 읽기 좋게.
                    if (item.titleKo.isNotEmpty) ...[
                      Text(
                        item.titleKo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(
                      item.aiBriefKo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.nameMuted,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.thumbnailUrl != null) ...[
                const SizedBox(width: 12),
                _NewsThumbnail(url: item.thumbnailUrl!),
              ],
            ],
          ),
          // 태그 칩은 표시하지 않는다(정보 가치 대비 공간 소모 — tags 데이터는
          // 향후 필터/검색용으로 모델에 유지). 하단은 원문 보기만 우측 정렬.
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '원문 보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.redSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 13, color: AppColors.redSoft),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openOriginal(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(item.originalLink),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('원문 링크를 열지 못했습니다.')),
    );
  }
}

/// 카드 우측 썸네일. 로드 실패(핫링크 차단 등) 시 깨진 아이콘 대신
/// 톤에 맞는 placeholder 박스를 유지해 레이아웃이 흔들리지 않게 한다.
class _NewsThumbnail extends StatelessWidget {
  const _NewsThumbnail({required this.url});

  final String url;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: _size,
          height: _size,
          color: AppColors.tileSurface,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 18,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _NewsEmptyCard extends StatelessWidget {
  const _NewsEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.tileSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Text(
            '표시할 소식이 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.nameMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '새 브리핑이 도착하면 이곳에 표시됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 발행 시각의 상대 표시(예: '2시간 전'). 일주일 이상 지난 소식은 날짜로 표기.
String newsRelativeTimeKo(DateTime publishedAt, DateTime now) {
  final diff = now.difference(publishedAt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${publishedAt.month}.${publishedAt.day}';
}
