import 'package:flutter/material.dart';

import '../models/standing_insight.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 정수 축에서 시작과 끝을 포함해 최대 4개의 겹치지 않는 눈금을 고른다.
/// 눈금 좌표도 반환한 실제 정숫값으로 계산해야 라벨과 데이터 선이 일치한다.
List<int> standingTrendAxisTicks(int start, int end) {
  if (end <= start) return [start];
  final valueCount = end - start + 1;
  final tickCount = valueCount < 4 ? valueCount : 4;
  return [
    for (var i = 0; i < tickCount; i++)
      start + ((end - start) * i / (tickCount - 1)).round(),
  ];
}

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
  const SummaryMetrics({
    super.key,
    required this.summary,
    required this.accent,
  });

  final SeasonSummary summary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                '시즌 성과',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '2026',
              style: TextStyle(
                color: AppColors.textEnded,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '우승',
                value: '${summary.wins}',
                icon: Icons.emoji_events_outlined,
                color: AppColors.warningAmber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: '포디움',
                value: '${summary.podiums}',
                icon: Icons.workspace_premium_outlined,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: '최고 순위',
                value: summary.bestFinish == null
                    ? '—'
                    : 'P${summary.bestFinish}',
                icon: Icons.trending_up_rounded,
                color: AppColors.blueSoft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: 'DNF',
                value: '${summary.dnfs}',
                icon: Icons.flag_outlined,
                color: AppColors.redSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Container(
        height: 76,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppColors.tileSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '시즌 순위 흐름',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (points.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    '현재 P${points.last.position}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '각 라운드 종료 기준 · 위쪽일수록 높은 순위',
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
              height: 154,
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
    const top = 12.0;
    const bottom = 25.0;
    const left = 30.0;
    const right = 14.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final observedMax = points
        .map((point) => point.position)
        .reduce((a, b) => a > b ? a : b);
    final maxPosition = observedMax < 2 ? 2 : observedMax;
    final span = maxPosition - 1;
    final firstRound = points.first.round;
    final lastRound = points.last.round;
    final roundSpan = lastRound == firstRound ? 1 : lastRound - firstRound;
    final gridPaint = Paint()
      ..color = AppColors.faintBorder
      ..strokeWidth = 1;
    for (final rank in standingTrendAxisTicks(1, maxPosition)) {
      final y = chart.top + chart.height * (rank - 1) / span;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _label(canvas, 'P$rank', Offset(0, y - 6));
    }

    final path = Path();
    final dots = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x =
          chart.left + chart.width * (points[i].round - firstRound) / roundSpan;
      final y = chart.top + chart.height * (points[i].position - 1) / span;
      final offset = Offset(x, y);
      dots.add(offset);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fillPath = Path.from(path)
      ..lineTo(dots.last.dx, chart.bottom)
      ..lineTo(dots.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < dots.length; i++) {
      final radius = i == dots.length - 1 ? 5.0 : 3.5;
      canvas.drawCircle(dots[i], radius + 2, Paint()..color = AppColors.card);
      canvas.drawCircle(dots[i], radius, Paint()..color = color);
    }

    for (final round in standingTrendAxisTicks(firstRound, lastRound)) {
      final x = chart.left + chart.width * (round - firstRound) / roundSpan;
      _centeredLabel(canvas, 'R$round', x, chart.bottom + 8);
    }
  }

  void _centeredLabel(Canvas canvas, String text, double centerX, double y) {
    final painter = _textPainter(text)..layout();
    painter.paint(canvas, Offset(centerX - painter.width / 2, y));
  }

  TextPainter _textPainter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: AppColors.textEnded,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  );

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = _textPainter(text)..layout();
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
