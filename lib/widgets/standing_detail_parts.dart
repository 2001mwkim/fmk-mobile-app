import 'package:flutter/material.dart';

import '../models/standing_insight.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

class DetailBackButton extends StatelessWidget {
  const DetailBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            height: 40,
            padding: const EdgeInsets.only(left: 10, right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  size: 21,
                  color: AppColors.white,
                ),
                SizedBox(width: 3),
                Text(
                  '순위로',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SummaryMetrics extends StatelessWidget {
  const SummaryMetrics({super.key, required this.summary});

  final SeasonSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _metric('우승', '${summary.wins}'),
        _metric('포디움', '${summary.podiums}'),
        _metric(
          '최고 순위',
          summary.bestFinish == null ? '—' : 'P${summary.bestFinish}',
        ),
        _metric('DNF', '${summary.dnfs}'),
      ],
    );
  }

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textEnded,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class StandingTrendCard extends StatelessWidget {
  const StandingTrendCard({
    super.key,
    required this.points,
    required this.color,
  });

  final List<StandingTrendPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시즌 순위 흐름',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '각 라운드 종료 후 챔피언십 순위',
            style: TextStyle(color: AppColors.textEnded, fontSize: 10),
          ),
          const SizedBox(height: 16),
          if (points.length < 2)
            const SizedBox(
              height: 90,
              child: Center(
                child: Text(
                  '추이를 표시할 라운드 기록이 부족합니다.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              key: const ValueKey('standing-trend-chart'),
              height: 126,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(points: points, color: color),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points, required this.color});

  final List<StandingTrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 16.0;
    const bottom = 24.0;
    const left = 26.0;
    const right = 12.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxPosition = points
        .map((point) => point.position)
        .reduce((a, b) => a > b ? a : b);
    final minPosition = points
        .map((point) => point.position)
        .reduce((a, b) => a < b ? a : b);
    final span = (maxPosition - minPosition).clamp(1, 30);
    final gridPaint = Paint()..color = AppColors.rowBorder;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final path = Path();
    final dots = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = chart.left + chart.width * i / (points.length - 1);
      final y =
          chart.top + chart.height * (points[i].position - minPosition) / span;
      final offset = Offset(x, y);
      dots.add(offset);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final dot in dots) {
      canvas.drawCircle(dot, 3.5, Paint()..color = color);
    }

    _label(canvas, 'P$minPosition', Offset(0, chart.top - 6));
    _label(
      canvas,
      'R${points.first.round}',
      Offset(chart.left - 5, chart.bottom + 7),
    );
    _label(
      canvas,
      'R${points.last.round}',
      Offset(chart.right - 18, chart.bottom + 7),
    );
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textEnded,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
