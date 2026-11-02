import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 반투명 유리 표면(2026-10 디자인 정리). 뒤 내용을 흐리게 비추고, 위쪽에
/// 얇은 빛 반사선을 둬서 면이 떠 있는 느낌을 준다 — 순검정 + 무채색 카드만으론
/// 앱이 밋밋하다는 피드백에 대한 답. 블러는 비용이 있어 탭 바·히어로처럼
/// 화면당 몇 곳에만 쓴다(목록 행마다 쓰지 말 것).
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blur = 24,
    this.tint,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// 유리 색. null 이면 최상위 텍스트색의 8% — 다크에선 흰 유리, 라이트에선
  /// 옅은 회색 유리가 된다.
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint ?? AppColors.white.withValues(alpha: 0.08),
            borderRadius: borderRadius,
            border: Border.all(
              color: AppColors.pureWhite.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
          child: DecoratedBox(
            // 위에서 떨어지는 빛 — 윗부분만 살짝 밝고 아래로 갈수록 사라진다.
            // (BoxDecoration 은 gradient 가 있으면 color 를 무시해서 면을 둘로 나눴다.)
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  AppColors.pureWhite.withValues(alpha: 0.07),
                  AppColors.pureWhite.withValues(alpha: 0),
                ],
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// 누르는 동안 살짝 작아졌다 돌아오는 탭 영역(iOS 카드 눌림). 물결 대신
/// 면 자체가 손가락에 반응해 "만지는" 느낌을 준다.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.98,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 140),
          child: widget.child,
        ),
      ),
    );
  }
}
