import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/track_outlines.dart';
import '../models/live_session.dart';
import '../services/live_positions_controller.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';
import 'live_team_radio_card.dart';

/// 라이브 센터 상단 트랙맵(2026-10).
///
/// 서킷 외곽선([TrackOutlineRepository]) 위에 22대를 팀 컬러 점 + TLA 로 그린다.
/// 좌표는 [LivePositionsController] 가 3초마다 받은 묶음을 몇 초 뒤처져 보간
/// 재생하므로 60fps 로 부드럽게 움직인다. 라이브 센터의 영상 지연 설정을 같은
/// 값으로 넘겨 타이밍 표와 같은 시점을 보여 준다.
///
/// 이름 라벨은 22대 모두 띄운다(겹쳐도 됨 — 2026-10 결정). 팀 라디오 재생 중인
/// 드라이버는 [liveTalkingRacingNumber] 로 강조한다.
class LiveTrackMapCard extends StatefulWidget {
  const LiveTrackMapCard({
    super.key,
    required this.snapshot,
    required this.delaySeconds,
    this.controllerOverride,
    this.outlineOverride,
    this.clock,
  });

  final LiveSessionSnapshot snapshot;
  final int delaySeconds;

  /// 테스트 주입용.
  final LivePositionsController? controllerOverride;
  final TrackOutline? outlineOverride;
  final DateTime Function()? clock;

  @override
  State<LiveTrackMapCard> createState() => _LiveTrackMapCardState();
}

class _LiveTrackMapCardState extends State<LiveTrackMapCard>
    with SingleTickerProviderStateMixin {
  late LivePositionsController _controller;
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  TrackOutline? _outline;
  bool _outlineLoaded = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    _controller.start();
    _ticker = createTicker((_) => _frame.value++)..start();
    _loadOutline();
  }

  LivePositionsController _createController() =>
      widget.controllerOverride ??
      LivePositionsController(delaySeconds: widget.delaySeconds);

  Future<void> _loadOutline() async {
    final outline =
        widget.outlineOverride ??
        await TrackOutlineRepository.forRace(widget.snapshot.raceId);
    if (!mounted) return;
    setState(() {
      _outline = outline;
      _outlineLoaded = true;
    });
  }

  @override
  void didUpdateWidget(covariant LiveTrackMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delaySeconds != widget.delaySeconds &&
        widget.controllerOverride == null) {
      // 지연 설정이 바뀌면 이전 시점의 타임라인을 버리고 새로 받는다.
      _controller.dispose();
      _controller = _createController()..start();
    }
    if (oldWidget.snapshot.raceId != widget.snapshot.raceId) {
      _outlineLoaded = false;
      _loadOutline();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    if (widget.controllerOverride == null) _controller.dispose();
    super.dispose();
  }

  Map<String, LiveDriverPosition> get _driversByNumber => {
    for (final d in widget.snapshot.classification)
      if (d.racingNumber != null) d.racingNumber!: d,
  };

  void _handleTap(TapUpDetails details, Size size, _MapGeometry geometry) {
    final now = (widget.clock ?? DateTime.now)();
    String? best;
    var bestDistance = 22.0;
    _controller.positionsAt(now).forEach((number, raw) {
      final p = geometry.toCanvas(geometry.outline.project(raw));
      final d = (p - details.localPosition).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = number;
      }
    });
    setState(() => _selected = best == _selected ? null : best);
  }

  @override
  Widget build(BuildContext context) {
    final outline = _outline;
    // 이 서킷 외곽선이 없으면(신규 서킷 등) 카드를 띄우지 않는다.
    if (_outlineLoaded && outline == null) return const SizedBox.shrink();
    final drivers = _driversByNumber;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '트랙맵',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                widget.delaySeconds > 0
                    ? '${widget.delaySeconds}초 지연'
                    : '몇 초 지연된 위치',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (outline == null)
            const SizedBox(height: 180)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final aspect = (outline.bounds.height / outline.bounds.width)
                    .clamp(0.5, 0.95);
                final size = Size(width, width * aspect + 28);
                final geometry = _MapGeometry(outline, size);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTapUp: (d) => _handleTap(d, size, geometry),
                    child: ColoredBox(
                      color: AppColors.tileSurface,
                      child: CustomPaint(
                        size: size,
                        painter: _TrackMapPainter(
                          geometry: geometry,
                          controller: _controller,
                          drivers: drivers,
                          selected: _selected,
                          clock: widget.clock ?? DateTime.now,
                          repaint: Listenable.merge([
                            _frame,
                            liveTalkingRacingNumber,
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          Text(
            _selected == null
                ? '차량을 탭하면 그 드라이버만 강조돼요'
                : '${drivers[_selected]?.code ?? '#$_selected'} 강조 중 · 다시 탭하면 해제',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// 외곽선 경계를 캔버스에 맞추는 변환.
class _MapGeometry {
  _MapGeometry(this.outline, this.size) {
    const pad = 22.0;
    final b = outline.bounds;
    scale = ((size.width - pad * 2) / b.width).clamp(0, double.infinity)
        .toDouble();
    final scaleY = (size.height - pad * 2) / b.height;
    if (scaleY < scale) scale = scaleY;
    origin = Offset(
      (size.width - b.width * scale) / 2 - b.left * scale,
      (size.height - b.height * scale) / 2 - b.top * scale,
    );
  }

  final TrackOutline outline;
  final Size size;
  late double scale;
  late Offset origin;

  Offset toCanvas(Offset projected) => origin + projected * scale;
}

class _TrackMapPainter extends CustomPainter {
  _TrackMapPainter({
    required this.geometry,
    required this.controller,
    required this.drivers,
    required this.selected,
    required this.clock,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final _MapGeometry geometry;
  final LivePositionsController controller;
  final Map<String, LiveDriverPosition> drivers;
  final String? selected;
  final DateTime Function() clock;

  static final Map<String, TextPainter> _labelCache = {};

  TextPainter _label(String text, Color color, bool emphasized) {
    final key = '$text|${color.toARGB32()}|$emphasized';
    return _labelCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: emphasized ? 12 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outline = geometry.outline;
    final path = Path();
    for (var i = 0; i < outline.points.length; i++) {
      final p = geometry.toCanvas(outline.points[i]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.dotInactive,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.resultChipSurface,
    );
    // 스타트/피니시: 외곽선 첫 점에 수직 눈금.
    final a = geometry.toCanvas(outline.points.first);
    final b = geometry.toCanvas(outline.points[2]);
    final dir = b - a;
    if (dir.distance > 0) {
      final normal = Offset(-dir.dy, dir.dx) / dir.distance * 8;
      canvas.drawLine(
        a - normal,
        a + normal,
        Paint()
          ..strokeWidth = 2
          ..color = AppColors.pureWhite,
      );
    }

    final talking = liveTalkingRacingNumber.value;
    final focus = talking ?? selected;
    final positions = controller.positionsAt(clock()).entries.toList()
      // 강조 차량을 맨 위에 그린다.
      ..sort((x, y) => (x.key == focus ? 1 : 0) - (y.key == focus ? 1 : 0));

    for (final entry in positions) {
      final number = entry.key;
      final p = geometry.toCanvas(outline.project(entry.value));
      final driver = drivers[number];
      final code = driver?.code ?? number;
      final accent = driver == null
          ? AppColors.muted
          : liveDriverAccent(driver.code);
      final emphasized = number == focus;
      final dimmed = focus != null && !emphasized;
      final alpha = dimmed ? 0.3 : 1.0;

      if (number == talking) {
        final pulse =
            (DateTime.now().millisecondsSinceEpoch % 1200) / 1200.0;
        canvas.drawCircle(
          p,
          7 + pulse * 12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = accent.withValues(alpha: 1 - pulse),
        );
      }
      canvas.drawCircle(
        p,
        emphasized ? 6.5 : 5,
        Paint()..color = accent.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        p,
        emphasized ? 6.5 : 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.background.withValues(alpha: alpha),
      );
      final label = _label(
        code,
        dimmed ? AppColors.muted : AppColors.textSoft,
        emphasized,
      );
      label.paint(canvas, p + Offset(7, -label.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TrackMapPainter old) =>
      old.geometry.size != geometry.size ||
      old.selected != selected ||
      old.drivers != drivers;
}
