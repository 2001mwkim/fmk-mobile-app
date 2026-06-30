import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 웹 app/page.tsx 의 "다음/진행중 그랑프리 히어로" 표면을 Flutter로 재현.
///
/// 웹 클래스:
///   rounded-3xl border border-red-500/30
///   bg-[linear-gradient(to_bottom_right,#1c0f0e,#1a1030,#141828)] p-5
///   + 대각선 반복 줄무늬(rgba(239,68,68,0.06), 108deg)
///   + 우상단 라디얼 글로우(rgba(239,68,68,0.18))
///
/// 일반 카드(AppCard)와 구분되는 히어로 전용 표면. 내용은 child 로 받는다.
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

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        // to bottom right: #1c0f0e -> #1a1030 -> #141828
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0F0E), Color(0xFF1A1030), Color(0xFF141828)],
        ),
      ),
      // 테두리는 내용 위에 그려 모서리에서 가려지지 않게 한다 (red-500/30).
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(BorderSide(color: Color(0x4DEF4444))),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          children: [
            // 대각선 반복 줄무늬
            const Positioned.fill(
              child: CustomPaint(painter: _DiagonalStripesPainter()),
            ),
            // 우상단 라디얼 글로우
            Positioned(
              right: -40,
              top: -32,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x2EEF4444), Color(0x00EF4444)],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹 repeating-linear-gradient(108deg, transparent 0 26px,
/// rgba(239,68,68,0.06) 26px 27px) 근사: 108° 방향 1px 줄을 27px 간격으로.
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter();

  static const double _spacing = 27;
  static const double _angle = 108 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x0FEF4444) // rgba(239,68,68,~0.06)
      ..strokeWidth = 1;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_angle);

    final extent = size.width + size.height;
    for (double x = -extent; x <= extent; x += _spacing) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter oldDelegate) => false;
}
