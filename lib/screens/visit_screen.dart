import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key});

  static const List<_VisitGuide> _guides = [
    _VisitGuide(
      title: '일본 그랑프리',
      description: '스즈카와 일본 여행을 함께 즐기는 현실적인 첫 F1 직관지',
      tags: ['첫 직관', '스즈카', '일본 여행'],
    ),
    _VisitGuide(
      title: '중국 그랑프리',
      description: '상하이 여행과 서킷 방문을 함께 고려할 수 있는 아시아 그랑프리',
      tags: ['상하이', '가까운 거리', '도시 여행'],
    ),
    _VisitGuide(
      title: '싱가포르 그랑프리',
      description: '야경, 공연, 레이스가 어우러지는 프리미엄 나이트 그랑프리',
      tags: ['나이트 레이스', '프리미엄', '도심형'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('직관 가이드')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _guides.length + 1,
          separatorBuilder: (_, index) => index == 0
              ? const SizedBox(height: 14)
              : const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _VisitHeader();
            }

            return _VisitGuideCard(guide: _guides[index - 1]);
          },
        ),
      ),
    );
  }
}

class _VisitHeader extends StatelessWidget {
  const _VisitHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '직관 가이드',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '포뮬러 매거진 코리아가 준비하는 아시아 그랑프리 직관 정보',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VisitGuideCard extends StatelessWidget {
  const _VisitGuideCard({required this.guide});

  final _VisitGuide guide;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            guide.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const _StatusBadge(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      guide.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in guide.tags) _TagBadge(label: tag),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '직관 정보 준비 중',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.red,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisitGuide {
  const _VisitGuide({
    required this.title,
    required this.description,
    required this.tags,
  });

  final String title;
  final String description;
  final List<String> tags;
}
