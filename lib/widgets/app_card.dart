// 색 인자는 테마 getter 기본값 때문에 private 필드로 받는다(아래 생성자 주석).
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// 공용 카드 표면. 원래 웹 components/Card.tsx(테두리 + 네이비 배경) 포팅이었으나
/// 2026-10 디자인 정리로 테두리를 없앴다 — 순검정 배경 위 무채색 카드는 명도
/// 차이만으로 충분히 구분되고, 모든 카드에 선을 두르면 화면이 칸막이처럼 보였다.
/// 강조가 꼭 필요한 곳만 borderColor 를 넘긴다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    // null 이면 현재 테마 팔레트의 card/border 를 쓴다(테마 도입으로
    // AppColors 가 getter 라 기본 인자로 못 쓴다).
    Color? backgroundColor,
    Color? borderColor,
  }) : _backgroundColor = backgroundColor,
       _borderColor = borderColor;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? _backgroundColor;
  final Color? _borderColor;

  Color get backgroundColor => _backgroundColor ?? AppColors.card;
  Color get borderColor => _borderColor ?? Colors.transparent;

  /// 웹에서 Card 를 <Link> 로 감싸 클릭 가능하게 쓰던 경우를 위한 옵션.
  final VoidCallback? onTap;

  static const BorderRadius _radius = AppRadius.cardBorder;

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
