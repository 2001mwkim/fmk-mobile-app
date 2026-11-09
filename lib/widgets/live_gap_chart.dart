import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/gap_history.dart';
import '../models/live_session.dart';
import '../services/gap_history_controller.dart';
import '../services/my_picks_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

/// 라이브 센터의 '갭 추이' 카드(레이스/스프린트 전용).
///
/// MultiViewer 의 Race Trace, Sofascore 모멘텀 그래프처럼 흐름을 그림 하나로
/// 보여준다(2026-11 개선 목록). 가로는 랩, 세로는 선두와의 간격 — 위가 선두다.
/// 기본은 상위 5명 + MY DRIVER, 칩으로 켜고 끈다.
class LiveGapChartCard extends StatefulWidget {
  const LiveGapChartCard({
    super.key,
    required this.snapshot,
    required this.delaySeconds,
    this.controllerFactory,
  });

  final LiveSessionSnapshot snapshot;
  final int delaySeconds;

  /// 테스트 주입 지점.
  final GapHistoryController Function(int delaySeconds)? controllerFactory;

  /// 카드를 띄울 세션인가 — 레이스/스프린트가 진행 중이거나 막 끝났을 때.
  static bool appliesTo(LiveSessionSnapshot snapshot) =>
      snapshot.isRaceOrSprint && snapshot.isDisplayable;

  @override
  State<LiveGapChartCard> createState() => _LiveGapChartCardState();
}

class _LiveGapChartCardState extends State<LiveGapChartCard> {
  static const int _defaultCount = 5;
  static const int _maxSelected = 8;

  GapHistoryController? _controller;

  /// 사용자가 칩으로 고른 드라이버. null 이면 기본(상위 5 + MY DRIVER).
  Set<String>? _selected;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant LiveGapChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delaySeconds != widget.delaySeconds) {
      _detach();
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    final controller =
        (widget.controllerFactory ??
        (delay) => GapHistoryController(delaySeconds: delay))(
          widget.delaySeconds,
        );
    controller.addListener(_onHistory);
    controller.start();
    _controller = controller;
  }

  void _detach() {
    _controller?.removeListener(_onHistory);
    _controller?.dispose();
    _controller = null;
  }

  void _onHistory() {
    if (mounted) setState(() {});
  }

  Set<String> _defaultSelection(List<String> drivers) {
    final mine = myPicksController.picks.driverCode;
    return {
      ...drivers.take(_defaultCount),
      if (mine != null && drivers.contains(mine)) mine,
    };
  }

  /// 화면에 가장 넓게 그려지는 드라이버 코드.
  String _widestCode(List<String> codes) {
    final painter = TextPainter(textDirection: TextDirection.ltr);
    var widest = '';
    var widestWidth = -1.0;
    for (final code in codes) {
      painter
        ..text = TextSpan(text: code, style: AppType.subhead)
        ..layout();
      if (painter.width > widestWidth) {
        widest = code;
        widestWidth = painter.width;
      }
    }
    painter.dispose();
    return widest;
  }

  void _toggle(String code, Set<String> current) {
    final next = {...current};
    if (!next.remove(code)) {
      if (next.length >= _maxSelected) return;
      next.add(code);
    }
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    final history = _controller?.history ?? GapHistory.empty;
    final drivers = history.drivers.isNotEmpty
        ? history.drivers
        : [for (final d in widget.snapshot.classification) d.code];
    final selected = _selected ?? _defaultSelection(drivers);
    final widestCode = _widestCode(drivers);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '갭 추이',
                  style: AppType.headline.copyWith(color: AppColors.white),
                ),
              ),
              if (history.hasData)
                Text(
                  '선두와의 간격 · ${history.laps.last.lap}랩까지',
                  style: AppType.caption.copyWith(
                    color: AppColors.textMuted,
                    fontFeatures: AppType.tabular,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!history.hasData)
            Text(
              '랩이 쌓이면 선두와의 간격 변화가 여기에 그려져요.',
              style: AppType.subhead.copyWith(color: AppColors.textMuted),
            )
          else ...[
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: Size.infinite,
                painter: _GapChartPainter(
                  series: [
                    for (final code in drivers)
                      if (selected.contains(code))
                        _Series(
                          code: code,
                          color: liveDriverAccent(code),
                          points: history.seriesFor(code),
                        ),
                  ],
                  firstLap: history.laps.first.lap,
                  lastLap: history.laps.last.lap,
                  gridColor: AppColors.hairline,
                  labelStyle: AppType.caption.copyWith(
                    color: AppColors.textMuted,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final code in drivers)
                  FilterChip(
                    key: ValueKey('gap-chip-$code'),
                    // 글자마다 폭이 달라(I, W 등) 칩 크기가 들쭉날쭉해지지 않게,
                    // 가장 넓은 코드를 투명하게 깔아 모든 칩을 그 폭에 맞춘다.
                    // 고정 폭과 달리 시스템 글자 크기를 키워도 잘리지 않는다.
                    label: Stack(
                      alignment: Alignment.center,
                      children: [
                        Visibility.maintain(
                          visible: false,
                          child: Text(widestCode),
                        ),
                        Text(code),
                      ],
                    ),
                    selected: selected.contains(code),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: selected.contains(code)
                          ? liveDriverAccent(code)
                          : AppColors.hairline,
                    ),
                    onSelected: (_) => _toggle(code, selected),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Series {
  const _Series({
    required this.code,
    required this.color,
    required this.points,
  });

  final String code;
  final Color color;
  final List<(int, double)> points;
}

/// 세로축 상한. 선택한 드라이버의 최대 간격을 5초 단위로 올리되 60초에서
/// 자른다 — 한 명이 크게 처지면 나머지 선이 바닥에 붙어 흐름이 안 보인다.
double gapChartCeiling(Iterable<double> gaps) {
  var maxGap = 0.0;
  for (final gap in gaps) {
    maxGap = math.max(maxGap, gap);
  }
  final rounded = (maxGap / 5).ceil() * 5.0;
  return rounded.clamp(5.0, 60.0);
}

class _GapChartPainter extends CustomPainter {
  _GapChartPainter({
    required this.series,
    required this.firstLap,
    required this.lastLap,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<_Series> series;
  final int firstLap;
  final int lastLap;
  final Color gridColor;
  final TextStyle labelStyle;

  static const double _leftAxis = 34;
  static const double _rightLabels = 34;
  static const double _bottomAxis = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final ceiling = gapChartCeiling(
      series.expand((s) => s.points.map((p) => p.$2)),
    );
    final plot = Rect.fromLTRB(
      _leftAxis,
      6,
      size.width - _rightLabels,
      size.height - _bottomAxis,
    );
    final lapSpan = math.max(1, lastLap - firstLap);
    double x(int lap) => plot.left + (lap - firstLap) / lapSpan * plot.width;
    double y(double gap) =>
        plot.top + math.min(gap, ceiling) / ceiling * plot.height;

    // 가로 눈금: 0(선두) 부터 상한까지 4칸.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final gap = ceiling * i / 4;
      final dy = y(gap);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), grid);
      _text(
        canvas,
        i == 0 ? '선두' : '+${gap.round()}s',
        Offset(0, dy - 7),
        maxWidth: _leftAxis - 4,
      );
    }
    _text(canvas, 'L$firstLap', Offset(plot.left, plot.bottom + 3));
    _text(
      canvas,
      'L$lastLap',
      Offset(plot.right - 24, plot.bottom + 3),
      maxWidth: 30,
    );

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      int? previousLap;
      for (final (lap, gap) in s.points) {
        final point = Offset(x(lap), y(gap));
        // 값이 빠진 랩(피트·랩다운)은 선을 끊는다.
        if (previousLap == null || lap - previousLap > 1) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        previousLap = lap;
      }
      canvas.drawPath(path, line);
      final (lastLapOf, lastGap) = s.points.last;
      _text(
        canvas,
        s.code,
        Offset(x(lastLapOf) + 4, y(lastGap) - 7),
        color: s.color,
        maxWidth: _rightLabels,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    Color? color,
    double maxWidth = 40,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(fontSize: 10, color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _GapChartPainter old) =>
      old.series != series ||
      old.firstLap != firstLap ||
      old.lastLap != lastLap ||
      old.gridColor != gridColor;
}
