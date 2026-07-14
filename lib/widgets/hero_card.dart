import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'circuit_map.dart';

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
    this.circuitAssetPath,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 탭 시 동작(예: 상세 이동). null 이면 비탭(시각 변화 없음).
  final VoidCallback? onTap;

  /// 지정 시 우측에 해당 서킷 아웃라인을 배경 장식으로 깐다
  /// (assets/circuits/*.svg — F1DB CC BY 4.0, 설정 화면에 출처 표기).
  final String? circuitAssetPath;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(22));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        // 160deg ≈ 위에서 아래로 살짝 좌측 기울기 — stop 0/0.55/1.
        gradient: LinearGradient(
          begin: Alignment(0.35, -1),
          end: Alignment(-0.35, 1),
          stops: [0.0, 0.55, 1.0],
          colors: [
            AppColors.heroGradTop,
            AppColors.heroGradMid,
            AppColors.heroGradBottom,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1FE23644), // rgba(226,54,68,0.12)
            blurRadius: 36,
            offset: Offset(0, 12),
          ),
        ],
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
        child: Stack(
          children: [
            // 대각선 레드 핀스트라이프
            const Positioned.fill(
              child: CustomPaint(painter: _DiagonalStripesPainter()),
            ),
            // 서킷 아웃라인 — 우측에 낮은 알파 레드(내용 가독성 우선).
            if (circuitAssetPath != null)
              Positioned(
                right: -28,
                top: 8,
                bottom: 8,
                width: 210,
                child: IgnorePointer(
                  child: CircuitOutline(
                    assetPath: circuitAssetPath!,
                    color: const Color(0x21F25C5C),
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

/// 웹 repeating-linear-gradient(115deg, transparent 0 26px,
/// rgba(242,92,92,0.05) 26px 28px) 근사: 115° 방향 2px 줄을 28px 간격으로.
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter();

  static const double _spacing = 28;
  static const double _angle = 115 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x0DF25C5C) // rgba(242,92,92,~0.05)
      ..strokeWidth = 2;

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
