import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 홈 "다음 그랑프리" 히어로 표면 — 디자인 핸드오프 Home v2.dc.html(1a).
///
/// 웹 원본 스펙:
///   border-radius 22 / border 1px rgba(242,92,92,0.22)
///   background linear-gradient(160deg, #221018 0%, #16121C 55%, #121218 100%)
///   box-shadow 0 12px 36px rgba(226,54,68,0.12)
///   + 대각선 핀스트라이프(115deg, rgba(242,92,92,0.05), 26px 간격)
///
/// 내용은 child 로 받는다. 시안의 텍스처는 아이덴티티 영역에만 깔리지만,
/// 알파가 낮아 카드 전체에 깔아도 시각 차가 없어 전면 페인트로 단순화.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 탭 시 동작(예: 상세 이동). null 이면 비탭(시각 변화 없음).
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.heroGradBottom,
        borderRadius: _radius,
      ),
      // 테두리는 내용 위에 그려 모서리에서 가려지지 않게 한다.
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x38F25C5C)), // rgba(242,92,92,0.22)
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
