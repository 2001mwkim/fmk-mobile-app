import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news_item.dart';
import '../services/news_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';

/// 소식 탭 — AI 가 정리한 해외 F1 주요 소식(한국어 브리핑) MVP 화면.
///
/// 데이터는 [NewsRepository] 계층에서 받아 렌더링만 한다(하드코딩 금지).
/// 지금은 [SampleNewsRepository](로컬 샘플)이고, 실서버 완성 시
/// `/api/news?limit=20&lang=ko` HTTP 구현으로 교체한다.
/// 정책: 원문 전문을 싣지 않고 2~3줄 브리핑 + 출처/원문 링크만 제공.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key, this.repository, this.nowOverride});

  /// 테스트/실서버 교체용 주입 지점.
  final NewsRepository? repository;
  final DateTime? nowOverride;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  late final NewsRepository _repository =
      widget.repository ?? const SampleNewsRepository();
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
          // 출처 · 발행 시간 (출처 명시 정책)
          Row(
            children: [
              Flexible(
                child: Text(
                  item.sourceName,
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
          Text(
            item.originalTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.aiBriefKo,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.nameMuted,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: item.tags.isEmpty
                    ? const SizedBox.shrink()
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in item.tags)
                            AppChip(label: tag, variant: AppChipVariant.mono),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              const Row(
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
            ],
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
