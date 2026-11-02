import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/broadcast_sync.dart';
import '../models/live_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// 중계 싱크 맞추기 시트. 측정된 지연(초)을 pop 결과로 돌려준다.
///
/// 실시간(지연 없는) 스냅샷을 기준으로 삼아야 하므로 라이브 센터의 지연
/// 컨트롤러가 아니라 전역 실시간 컨트롤러를 [readSnapshot]/[refresh] 로 넘긴다.
/// 계산 규칙은 `models/broadcast_sync.dart`.
class BroadcastSyncSheet extends StatefulWidget {
  const BroadcastSyncSheet({
    super.key,
    required this.readSnapshot,
    required this.refresh,
    this.clock = DateTime.now,
  });

  final LiveSessionSnapshot? Function() readSnapshot;
  final Future<void> Function() refresh;
  final DateTime Function() clock;

  @override
  State<BroadcastSyncSheet> createState() => _BroadcastSyncSheetState();
}

enum _SyncMode { lap, clock, unavailable }

class _BroadcastSyncSheetState extends State<BroadcastSyncSheet> {
  late _SyncMode _mode;

  // 시계 기준: 시트를 연 시점의 스냅샷과 목표 남은 시간.
  DateTime? _clockSnapshotAt;
  Duration? _clockSnapshotRemaining;
  Duration? _clockTarget;

  // 측정 결과.
  DateTime? _tappedAt;
  List<LiveLapStart> _lapStarts = const [];
  int? _tvLap;
  int? _delay;
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    _mode = _resolveMode(widget.readSnapshot());
  }

  _SyncMode _resolveMode(LiveSessionSnapshot? snapshot) {
    if (snapshot == null || snapshot.status != LiveSessionStatus.live) {
      return _SyncMode.unavailable;
    }
    if (snapshot.isRaceOrSprint) {
      return snapshot.recentLapStarts.isEmpty
          ? _SyncMode.unavailable
          : _SyncMode.lap;
    }
    final remaining = parseSessionClock(snapshot.remainingTime);
    final at = DateTime.tryParse(snapshot.updatedAt);
    if (snapshot.clockStopped || remaining == null || at == null) {
      return _SyncMode.unavailable;
    }
    final target = clockSyncTarget(
      now: widget.clock(),
      snapshotAt: at,
      snapshotRemaining: remaining,
    );
    if (target == null) return _SyncMode.unavailable;
    _clockSnapshotAt = at;
    _clockSnapshotRemaining = remaining;
    _clockTarget = target;
    return _SyncMode.clock;
  }

  Future<void> _onTap() async {
    final tappedAt = widget.clock();
    unawaited(HapticFeedback.mediumImpact());
    if (_mode == _SyncMode.clock) {
      setState(() {
        _tappedAt = tappedAt;
        _delay = delayFromClockTap(
          tappedAt: tappedAt,
          target: _clockTarget!,
          snapshotAt: _clockSnapshotAt!,
          snapshotRemaining: _clockSnapshotRemaining!,
        );
      });
      return;
    }
    // 랩 기준: 폴링 간격(최대 10초) 때문에 방금 시작된 랩이 아직 없을 수 있어
    // 누른 직후 한 번 새로 받아 온다.
    setState(() => _measuring = true);
    try {
      await widget.refresh();
    } catch (_) {
      // 새로 받기 실패 — 가지고 있는 스냅샷으로 계산한다.
    }
    if (!mounted) return;
    final starts = widget.readSnapshot()?.recentLapStarts ?? const [];
    final lap = defaultTvLap(tappedAt: tappedAt, lapStarts: starts);
    setState(() {
      _measuring = false;
      _tappedAt = tappedAt;
      _lapStarts = starts;
      _tvLap = lap;
      _delay = lap == null
          ? null
          : delayFromLapTap(tappedAt: tappedAt, tvLap: lap, lapStarts: starts);
    });
  }

  void _shiftLap(int delta) {
    final current = _tvLap;
    final tappedAt = _tappedAt;
    if (current == null || tappedAt == null) return;
    final next = current + delta;
    if (!_lapStarts.any((start) => start.lap == next)) return;
    setState(() {
      _tvLap = next;
      _delay = delayFromLapTap(
        tappedAt: tappedAt,
        tvLap: next,
        lapStarts: _lapStarts,
      );
    });
  }

  void _reset() => setState(() {
    _tappedAt = null;
    _tvLap = null;
    _delay = null;
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '중계 화면에 맞추기',
              style: AppType.title.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _instruction,
              style: AppType.subhead.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (_mode == _SyncMode.unavailable)
              const SizedBox.shrink()
            else if (_tappedAt == null)
              _TapTarget(
                label: _mode == _SyncMode.clock
                    ? formatSessionClock(_clockTarget!)
                    : '랩 카운터',
                busy: _measuring,
                onTap: _measuring ? null : _onTap,
              )
            else
              _Result(
                delay: _delay,
                tvLap: _mode == _SyncMode.lap ? _tvLap : null,
                canLapDown:
                    _tvLap != null &&
                    _lapStarts.any((start) => start.lap == _tvLap! - 1),
                canLapUp:
                    _tvLap != null &&
                    _lapStarts.any((start) => start.lap == _tvLap! + 1),
                onLapDown: () => _shiftLap(-1),
                onLapUp: () => _shiftLap(1),
              ),
            const SizedBox(height: 16),
            if (_tappedAt != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _reset,
                      child: const Text('다시 재기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _delay == null
                          ? null
                          : () => Navigator.pop(context, _delay),
                      child: const Text('이 지연으로 보기'),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
          ],
        ),
      ),
    );
  }

  String get _instruction {
    switch (_mode) {
      case _SyncMode.lap:
        return '중계 화면의 랩 카운터가 다음 랩으로 바뀌는 순간 아래 버튼을 누르세요.';
      case _SyncMode.clock:
        return '중계 화면의 남은 시간이 ${formatSessionClock(_clockTarget!)} 이 되는 순간 아래 버튼을 누르세요.';
      case _SyncMode.unavailable:
        return '세션이 진행 중일 때만 맞출 수 있어요. 레이스는 랩 카운터, 연습·퀄리파잉은 남은 시간 시계를 기준으로 재요.';
    }
  }
}

class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.label, required this.busy, this.onTap});

  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '지금 바뀌었어요',
      child: Material(
        color: AppColors.red,
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          borderRadius: AppRadius.cardBorder,
          onTap: onTap,
          child: SizedBox(
            height: 132,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppType.title.copyWith(
                            color: AppColors.onAccent,
                            fontFeatures: AppType.tabular,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '지금 바뀌었어요',
                          style: AppType.subhead.copyWith(
                            color: AppColors.onAccent,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.delay,
    required this.tvLap,
    required this.canLapDown,
    required this.canLapUp,
    required this.onLapDown,
    required this.onLapUp,
  });

  final int? delay;
  final int? tvLap;
  final bool canLapDown;
  final bool canLapUp;
  final VoidCallback onLapDown;
  final VoidCallback onLapUp;

  @override
  Widget build(BuildContext context) {
    final value = delay;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tileSurface,
        borderRadius: AppRadius.cardBorder,
      ),
      child: Column(
        children: [
          Text(
            value == null ? '측정 실패' : '$value초',
            style: AppType.largeTitle.copyWith(
              color: AppColors.white,
              fontFeatures: AppType.tabular,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null
                ? '0~$kMaxBroadcastDelaySeconds초 범위를 벗어났어요. 랩을 고치거나 다시 재 주세요.'
                : '중계가 실제보다 이만큼 늦어요',
            textAlign: TextAlign.center,
            style: AppType.subhead.copyWith(color: AppColors.textMuted),
          ),
          if (tvLap != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: canLapDown ? onLapDown : null,
                  tooltip: '한 랩 전',
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 12),
                Text(
                  '중계에 나온 랩 $tvLap',
                  style: AppType.headline.copyWith(
                    color: AppColors.white,
                    fontFeatures: AppType.tabular,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed: canLapUp ? onLapUp : null,
                  tooltip: '한 랩 후',
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
