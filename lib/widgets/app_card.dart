import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

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
    this.backgroundColor = AppColors.card,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;

  /// 웹에서 Card 를 <Link> 로 감싸 클릭 가능하게 쓰던 경우를 위한 옵션.
  final VoidCallback? onTap;

  static const BorderRadius _radius = AppRadius.mediumBorder;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: _radius,
        border: Border.fromBorderSide(BorderSide(color: borderColor)),
      ),
      child: content,
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
