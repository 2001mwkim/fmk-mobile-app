import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../services/position_debug_service.dart';
import '../theme/app_colors.dart';

// Position.z 실험 화면 (2026-09 feasibility POC).
//
// **디버그 빌드 전용이며 프로덕션 UI 가 아니다.** 라이브 센터에 추가하지 않고
// 설정 › 개발자 섹션에서만 진입한다. 기존 liveSessionController 를 쓰지 않고
// 자체 타이머로 /debug/position 만 폴링하므로 기존 라이브 동작에 영향이 없다.
//
// 이 화면으로 확인하려는 것:
//  1. 차량이 정상적으로 움직이는가(좌표가 살아 있는가)
//  2. 궤적이 실제 서킷 모양을 그리는가(좌표계·방향 검증)
//  3. 1Hz / 2Hz / 5Hz 체감 차이
//  4. 보간 ON/OFF 차이 — 낮은 주기로도 부드러운가
class PositionDebugScreen extends StatefulWidget {
  const PositionDebugScreen({super.key});

  @override
  State<PositionDebugScreen> createState() => _PositionDebugScreenState();
}

class _PositionDebugScreenState extends State<PositionDebugScreen>
    with SingleTickerProviderStateMixin {
  final PositionDebugService _service = PositionDebugService();

  PositionSamplingMode _mode = PositionSamplingMode.hz1;
  bool _interpolate = true;
  bool _showTrail = true;

  Timer? _pollTimer;
  /// 60fps 리페인트용 — 네트워크 주기와 화면 프레임률을 분리한다.
  late final Ticker _ticker = createTicker(_onTick);

  PositionSnapshot? _snapshot;
  String? _error;

  /// 보간 구간의 양 끝.
  List<PositionEntry> _previousPositions = const <PositionEntry>[];
  List<PositionEntry> _targetPositions = const <PositionEntry>[];
  DateTime? _targetReceivedAt;
  Duration _lastInterval = const Duration(milliseconds: 500);

  /// 화면에 실제로 그리는 위치(보간 결과).
  List<PositionEntry> _renderPositions = const <PositionEntry>[];

  /// 좌표 자동 맞춤 경계(누적).
  PositionBounds? _bounds;

  /// 궤적 — 서킷 모양이 그려지는지 눈으로 확인하는 용도.
  final List<Offset> _trail = <Offset>[];

  int _updateCount = 0;
  int _totalPayloadBytes = 0;
  DateTime? _firstUpdateAt;

  @override
  void initState() {
    super.initState();
    _restartPolling();
    _ticker.start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _restartPolling() {
    _pollTimer?.cancel();
    // 폴링 주기 = 해당 모드의 갱신 주기. RAW 는 서버 원본 주기를 놓치지 않게 촘촘히.
    final interval = _mode.expectedInterval;
    _lastInterval = interval;
    _poll();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  Future<void> _poll() async {
    final result = await _service.fetch(_mode);
    if (!mounted) return;

    setState(() {
      if (!result.ok) {
        _error = result.error;
        return;
      }
      _error = null;
      final snapshot = result.snapshot!;
      _snapshot = snapshot;

      if (snapshot.positions.isNotEmpty) {
        // 보간 구간 갱신: 직전 목표가 새 출발점이 된다.
        _previousPositions = _renderPositions.isEmpty
            ? snapshot.positions
            : _renderPositions;
        _targetPositions = snapshot.positions;
        final now = DateTime.now();
        if (_targetReceivedAt != null) {
          final gap = now.difference(_targetReceivedAt!);
          // 비정상적으로 긴 공백은 보간 구간으로 쓰지 않는다(튀는 이동 방지).
          if (gap > Duration.zero && gap < const Duration(seconds: 3)) {
            _lastInterval = gap;
          }
        }
        _targetReceivedAt = now;
        _firstUpdateAt ??= now;
        _updateCount += 1;
        _totalPayloadBytes += snapshot.payloadBytes;

        _bounds = (_bounds ?? PositionBounds.fromEntries(snapshot.positions))
            ?.extend(snapshot.positions);
      }
    });
  }

  void _onTick(Duration _) {
    final target = _targetPositions;
    if (target.isEmpty) return;

    List<PositionEntry> next;
    if (!_interpolate) {
      next = target;
    } else {
      final receivedAt = _targetReceivedAt;
      if (receivedAt == null) {
        next = target;
      } else {
        final elapsed = DateTime.now().difference(receivedAt).inMilliseconds;
        final span = _lastInterval.inMilliseconds.clamp(1, 5000);
        // 외삽 금지 — t 는 1 에서 멈춘다(늦게 오면 마지막 위치 유지).
        final t = (elapsed / span).clamp(0.0, 1.0);
        next = interpolatePositions(_previousPositions, target, t);
      }
    }

    setState(() {
      _renderPositions = next;
      if (_showTrail && next.isNotEmpty) {
        _trail.add(Offset(next.first.x, next.first.y));
        if (_trail.length > 4000) _trail.removeRange(0, 1000);
      }
    });
  }

  void _resetMeasurements() {
    setState(() {
      _updateCount = 0;
      _totalPayloadBytes = 0;
      _firstUpdateAt = null;
      _trail.clear();
      _bounds = null;
    });
  }

  double get _observedUpdatesPerSecond {
    final since = _firstUpdateAt;
    if (since == null || _updateCount == 0) return 0;
    final seconds = DateTime.now().difference(since).inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return _updateCount / seconds;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        title: const Text('Position 실험 (디버그)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildControls(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.tileSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _renderPositions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error != null
                                ? '연결 실패\n$_error'
                                : snapshot == null
                                ? '연결 중…'
                                : !snapshot.enabled
                                ? 'collector 에서 실험이 꺼져 있습니다.\n'
                                      'POSITION_EXPERIMENT=1 로 실행하세요.'
                                : 'Position 데이터 대기 중…\n'
                                      '(세션이 진행 중이어야 좌표가 옵니다)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : CustomPaint(
                        painter: _PositionMapPainter(
                          positions: _renderPositions,
                          bounds: _bounds,
                          trail: _showTrail ? _trail : const <Offset>[],
                        ),
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
            _buildMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final mode in PositionSamplingMode.values)
                ChoiceChip(
                  label: Text(mode.label),
                  selected: _mode == mode,
                  onSelected: (_) {
                    setState(() => _mode = mode);
                    _resetMeasurements();
                    _restartPolling();
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('보간', style: TextStyle(fontSize: 13)),
                  value: _interpolate,
                  onChanged: (value) => setState(() => _interpolate = value),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('궤적', style: TextStyle(fontSize: 13)),
                  value: _showTrail,
                  onChanged: (value) {
                    setState(() {
                      _showTrail = value;
                      if (!value) _trail.clear();
                    });
                  },
                ),
              ),
              IconButton(
                tooltip: '측정 초기화',
                onPressed: _resetMeasurements,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final snapshot = _snapshot;
    final perMinuteKb = _observedUpdatesPerSecond *
        (_updateCount > 0 ? _totalPayloadBytes / _updateCount : 0) *
        60 /
        1024;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tileSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 11,
          height: 1.6,
          color: AppColors.textMuted,
          fontFamily: 'Pretendard',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '차량 ${_renderPositions.length}대 · 관측 '
              '${_observedUpdatesPerSecond.toStringAsFixed(2)} upd/s · '
              '${perMinuteKb.toStringAsFixed(1)} KB/분',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.white,
              ),
            ),
            Text(
              'payload ${snapshot?.payloadBytes ?? 0}B · '
              'RTT ${snapshot?.fetchMs ?? 0}ms · '
              'decode ${snapshot?.decodeStrategy ?? "(미확정)"}',
            ),
            Text(
              '서버 raw ${snapshot?.rawUpdatesPerSecond.toStringAsFixed(2) ?? "0"} msg/s · '
              '마지막 수신 ${snapshot?.lastUpdateAgeMs ?? "-"}ms 전'
              '${snapshot?.mock == true ? " · ⚠ MOCK 데이터" : ""}',
            ),
          ],
        ),
      ),
    );
  }
}

/// 좌표를 화면에 자동 맞춤해 그리는 디버그 페인터.
class _PositionMapPainter extends CustomPainter {
  _PositionMapPainter({
    required this.positions,
    required this.bounds,
    required this.trail,
  });

  final List<PositionEntry> positions;
  final PositionBounds? bounds;
  final List<Offset> trail;

  @override
  void paint(Canvas canvas, Size size) {
    final box = bounds;
    if (box == null || !box.isValid) return;

    const padding = 24.0;
    final scale = ((size.width - padding * 2) / box.width)
        .clamp(0.0, (size.height - padding * 2) / box.height);
    final offsetX =
        (size.width - box.width * scale) / 2 - box.minX * scale;
    // F1 좌표계는 Y 가 위로 증가한다고 알려져 있어 화면 좌표로 뒤집는다.
    // 실제 방향은 세션에서 궤적 모양으로 확인해야 한다.
    final offsetY =
        (size.height + box.height * scale) / 2 + box.minY * scale;

    Offset project(double x, double y) =>
        Offset(x * scale + offsetX, -y * scale + offsetY);

    if (trail.length > 1) {
      final path = Path()
        ..moveTo(project(trail.first.dx, trail.first.dy).dx,
            project(trail.first.dx, trail.first.dy).dy);
      for (final point in trail.skip(1)) {
        final projected = project(point.dx, point.dy);
        path.lineTo(projected.dx, projected.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.textMuted.withValues(alpha: 0.45),
      );
    }

    final dotPaint = Paint()..color = AppColors.red;
    final textStyle = TextStyle(
      color: AppColors.pureWhite,
      fontSize: 9,
      fontWeight: FontWeight.w700,
    );

    for (final entry in positions) {
      final point = project(entry.x, entry.y);
      canvas.drawCircle(point, 5, dotPaint);
      final painter = TextPainter(
        text: TextSpan(text: entry.racingNumber, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, point + Offset(6, -painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PositionMapPainter oldDelegate) => true;
}
