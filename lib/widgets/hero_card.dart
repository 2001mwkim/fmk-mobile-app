import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 홈 "다음 그랑프리" 히어로 표면 — 디자인 핸드오프 Home v2.dc.html(1a).
///
/// 웹 원본은 웜(레드-퍼플) 그라데이션 배경(#221018→#16121C→#121218)이었으나,
/// 나머지 카드(AppCard #141828 쿨 네이비)와 배경 온도가 달라 홈에서 "다른
/// 디자인의 박스"처럼 튀었다. 배경은 공용 카드와 동일한 네이비로 통일하고,
/// 위계·브랜드 강조는 레드 테두리(rgba(242,92,92,0.22))만으로 준다
/// ("강조는 액센트로, 바탕은 공유"). 테두리 원본 스펙은 border 1px 유지.
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
        // 공용 카드(AppCard)와 동일한 네이비로 통일 — 아래 레드 테두리만이
        // 히어로를 구분하는 액센트가 된다.
        color: AppColors.card,
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
