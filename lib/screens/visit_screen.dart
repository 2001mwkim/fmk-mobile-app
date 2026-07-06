import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';

// 웹 직관 페이지 전용 색.
const Color _muted = AppColors.muted; // #7880a0
const Color _subtitle = AppColors.heroSub; // #8088a8 (헤더 설명)
const Color _descMuted = AppColors.textMuted; // #959bb6 (가이드 설명)
const Color _nameMuted = AppColors.nameMuted; // #aab0cc
const Color _tileSurface = AppColors.tileSurface; // #0e1018

class VisitScreen extends StatelessWidget {
  const VisitScreen({super.key});

  static const List<_VisitGuide> _guides = [
    _VisitGuide(title: '일본 그랑프리', description: '근본 넘치는 스즈카 서킷에서 펼쳐지는 그랑프리'),
    _VisitGuide(title: '중국 그랑프리', description: '상하이 여행을 함께 즐길 수 있는 그랑프리'),
    _VisitGuide(title: '싱가포르 그랑프리', description: '야경과 공연을 함께 즐기는 나이트 그랑프리'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _VisitHeader(),
            const SizedBox(height: 14),
            const _GuideProgressCard(),
            const SizedBox(height: 12),
            for (final guide in VisitScreen._guides) ...[
              _VisitGuideCard(guide: guide),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitHeader extends StatelessWidget {
  const _VisitHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FORMULA MAGAZINE KOREA',
            style: TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '직관 가이드',
            style: TextStyle(
              fontSize: 26,
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '포뮬러 매거진 코리아가 준비하는 아시아 그랑프리 직관 정보',
            style: TextStyle(
              fontSize: 13,
              color: _subtitle,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideProgressCard extends StatelessWidget {
  const _GuideProgressCard();

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0F0E), Color(0xFF1A1030), Color(0xFF141828)],
        ),
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x33EF4444)), // red-500/20
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GUIDE IN PROGRESS',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.redSoft,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '아시아 그랑프리 직관 정보 준비 중',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '이동, 숙소, 서킷 접근성, 여행 동선을 함께 볼 수 있는 가이드를 순차적으로 준비하고 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: _nameMuted,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitGuideCard extends StatelessWidget {
  const _VisitGuideCard({required this.guide});

  final _VisitGuide guide;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
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
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const AppChip(label: '가이드 준비 중', variant: AppChipVariant.neutral),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            guide.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: _descMuted,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const _RelatedGrandPrixRow(),
        ],
      ),
    );
  }
}

class _RelatedGrandPrixRow extends StatelessWidget {
  const _RelatedGrandPrixRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            '관련 그랑프리',
            style: TextStyle(
              fontSize: 12,
              color: _nameMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '직관 정보 준비 중',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.redSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitGuide {
  const _VisitGuide({required this.title, required this.description});

  final String title;
  final String description;
}
