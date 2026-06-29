import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 웹 components/Card.tsx 의 Flutter 포팅.
///
/// 웹 클래스:
///   rounded-2xl border border-white/10 bg-[#141828]
///   shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]
///
/// - rounded-2xl => BorderRadius 16
/// - border-white/10 => AppColors.border
/// - bg-[#141828] => AppColors.card
/// - 상단 inner-highlight => 1px 흰색 4% 라인으로 근사 (Flutter는 inset shadow 미지원)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 웹에서 Card 를 <Link> 로 감싸 클릭 가능하게 쓰던 경우를 위한 옵션.
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    final surface = DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: _radius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      // 웹 inset 상단 하이라이트(rgba(255,255,255,0.04)) 근사.
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: _radius,
          border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
        ),
        child: content,
      ),
    );

    if (onTap == null) {
      return surface;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: _radius,
      child: InkWell(borderRadius: _radius, onTap: onTap, child: surface),
    );
  }
}
