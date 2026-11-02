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
///
/// 카드는 라이브가 아닐 때도 뜬다(사용자 요청 2026-10) — 그때는 다음 GP 의
/// 서킷 외곽선만 그리고 좌표 컨트롤러를 만들지 않는다. 좌표 폴링은 여전히
/// 세션 진행 중 + positionsAvailable 일 때만이라 요청 비용은 그대로다.
class LiveTrackMapCard extends StatefulWidget {
  const LiveTrackMapCard({
    super.key,
    this.snapshot,
    this.raceId,
    required this.delaySeconds,
    this.controllerOverride,
    this.outlineOverride,
    this.clock,
  });

  /// 라이브 스냅샷(없으면 외곽선만).
  final LiveSessionSnapshot? snapshot;

  /// 외곽선을 고를 GP. 없으면 [snapshot] 의 raceId.
  final String? raceId;
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
  LivePositionsController? _controller;
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  TrackOutline? _outline;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _frame.value++);
    _syncCars();
    _loadOutline();
  }

  String? get _raceId => widget.raceId ?? widget.snapshot?.raceId;

  /// 차량을 그릴지 — 세션 진행 중이고 collector 가 좌표를 줄 때만.
  bool get _showCars {
    if (widget.controllerOverride != null) return true;
    final s = widget.snapshot;
    return s != null &&
        s.status == LiveSessionStatus.live &&
        s.positionsAvailable;
  }

  /// [_showCars] 에 맞춰 좌표 컨트롤러·프레임 티커를 켜고 끈다(평소엔 0 요청).
  void _syncCars() {
    if (_showCars && _controller == null) {
      _controller =
          (widget.controllerOverride ??
                LivePositionsController(delaySeconds: widget.delaySeconds))
            ..start();
      if (!_ticker.isActive) _ticker.start();
    } else if (!_showCars && _controller != null) {
      if (widget.controllerOverride == null) _controller!.dispose();
      _controller = null;
      _ticker.stop();
    }
  }

  Future<void> _loadOutline() async {
    final outline =
        widget.outlineOverride ?? await TrackOutlineRepository.forRace(_raceId);
    if (!mounted) return;
    setState(() => _outline = outline);
  }

  @override
  void didUpdateWidget(covariant LiveTrackMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delaySeconds != widget.delaySeconds &&
        widget.controllerOverride == null &&
        _controller != null) {
      // 지연 설정이 바뀌면 이전 시점의 타임라인을 버리고 새로 받는다.
      _controller!.dispose();
      _controller = null;
    }
    _syncCars();
    final oldRaceId = oldWidget.raceId ?? oldWidget.snapshot?.raceId;
    if (oldRaceId != _raceId) {
      // 다른 GP 로 바뀌면 이전 서킷을 잠깐이라도 보여주지 않는다.
      _outline = null;
      _loadOutline();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    if (widget.controllerOverride == null) _controller?.dispose();
    super.dispose();
  }

  Map<String, LiveDriverPosition> get _driversByNumber => {
    for (final d
        in widget.snapshot?.classification ?? const <LiveDriverPosition>[])
      if (d.racingNumber != null) d.racingNumber!: d,
  };

  void _handleTap(TapUpDetails details, Size size, _MapGeometry geometry) {
    final controller = _controller;
    if (controller == null) return;
    final now = (widget.clock ?? DateTime.now)();
    String? best;
    var bestDistance = 22.0;
    controller.positionsAt(now).forEach((number, raw) {
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
    // 외곽선이 준비되기 전·없을 때(신규 서킷 등)는 카드를 그리지 않는다.
    // 로딩 중에 빈 자리를 잡았다가 '외곽선 없음'으로 사라지면 아래 카드들이
    // 위로 튄다(카드가 늘 뜨게 되면서 드러난 문제).
    if (outline == null) return const SizedBox.shrink();
    final drivers = _driversByNumber;
    final cars = _controller != null;
    final live = widget.snapshot?.status == LiveSessionStatus.live;
    final subtitle = cars
        ? (widget.delaySeconds > 0
              ? '${widget.delaySeconds}초 지연'
              : '몇 초 지연된 위치')
        : live
        ? '차량 위치 준비 중'
        : '세션 중 차량 위치 표시';

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
                subtitle,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          if (cars) ...[
            const SizedBox(height: 8),
            Text(
              _selected == null
                  ? '차량을 탭하면 그 드라이버만 강조돼요'
                  : '${drivers[_selected]?.code ?? '#$_selected'} 강조 중 · 다시 탭하면 해제',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
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
    scale = ((size.width - pad * 2) / b.width)
        .clamp(0, double.infinity)
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

  /// null 이면 외곽선만 그린다(세션 밖).
  final LivePositionsController? controller;
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

    final controller = this.controller;
    if (controller == null) return;
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
        final pulse = (DateTime.now().millisecondsSinceEpoch % 1200) / 1200.0;
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
      old.drivers != drivers ||
      old.controller != controller;
}
