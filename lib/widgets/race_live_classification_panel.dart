import 'package:flutter/material.dart';

import '../models/live_session.dart';
import '../theme/app_colors.dart';

/// 웹 components/live/RaceLiveClassificationPanel.tsx 의 Flutter 이식.
///
/// snapshot 이 없거나 표시 불가/다른 그랑프리/순위 비어있으면 렌더하지 않는다.
/// 실데이터 연결 전에는 [snapshot] 이 null 로 들어와 화면에 노출되지 않는다.
class RaceLiveClassificationPanel extends StatefulWidget {
  const RaceLiveClassificationPanel({
    super.key,
    required this.snapshot,
    required this.raceId,
    this.isStale = false,
    this.now,
  });

  final LiveSessionSnapshot? snapshot;
  final String raceId;

  /// 데이터 연결이 잠깐 흔들려 마지막 순위표를 유지 중인 상태(3분 초과).
  final bool isStale;
  final DateTime? now;

  @override
  State<RaceLiveClassificationPanel> createState() =>
      _RaceLiveClassificationPanelState();
}

class _RaceLiveClassificationPanelState
    extends State<RaceLiveClassificationPanel> {
  bool _expanded = false;

  static const Color _muted = Color(0xFF7880A0);
  static const Color _faint = Color(0xFF5B6178);
  static const Color _nameMuted = Color(0xFFAAB0CC);
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    if (s == null ||
        !isLiveSnapshotDisplayable(s, widget.now) ||
        s.raceId != widget.raceId ||
        s.classification.isEmpty) {
      return const SizedBox.shrink();
    }

    final ended = s.isEnded && !isLiveSnapshotSessionActive(s, widget.now);
    final raceLike = s.isRaceOrSprint;
    final topThree = s.classification.take(3).toList();
    final remaining = s.classification.skip(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141019),
          borderRadius: _radius,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(
            color: ended ? AppColors.border : const Color(0x66EF4444),
          ),
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(s, ended),
              _columnHeader(s),
              for (final d in topThree)
                _ClassificationRow(driver: d, raceLike: raceLike),
              if (remaining.isNotEmpty) _expander(remaining, ended, raceLike),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(LiveSessionSnapshot s, bool ended) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: ended
              ? const [Color(0x08FFFFFF), Color(0x00FFFFFF)]
              : const [Color(0x14EF4444), Color(0x00EF4444)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _StatusBadge(ended: ended),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        s.sessionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (s.showLap) ...[
                      const SizedBox(width: 8),
                      _LapChip(text: 'LAP ${s.currentLap}/${s.totalLaps}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _LiveClock(label: s.updatedAtLabel, ended: ended),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.classificationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _nameMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.isStale) ...[
                const _StaleBadge(),
                const SizedBox(width: 8),
              ],
              const SizedBox(width: 10),
              Text(
                '${s.classification.length} DRIVERS',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'Pretendard',
                  color: _faint,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _columnHeader(LiveSessionSnapshot s) {
    const style = TextStyle(
      fontSize: 9,
      fontFamily: 'Pretendard',
      color: _faint,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x33000000), // black/20
        border: Border(top: BorderSide(color: Color(0x12FFFFFF))), // white/7
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 22, child: Text('POS', style: style)),
          const SizedBox(width: 11),
          const Expanded(child: Text('DRIVER', style: style)),
          Text(s.gapColumnLabel, style: style),
        ],
      ),
    );
  }

  Widget _expander(
    List<LiveDriverPosition> remaining,
    bool ended,
    bool raceLike,
  ) {
    final accent = ended ? _nameMuted : AppColors.redSoft;
    final start = remaining.first.position;
    final end = remaining.last.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: const Color(0x33000000),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x0DFFFFFF)),
                ), // white/5
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expanded ? '순위 접기' : '4위 이하 순위 보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? '$start-$end위' : '+ ${remaining.length}명 더',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'Pretendard',
                          color: _muted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _expanded ? '↑' : '↓',
                        style: TextStyle(fontSize: 11, color: accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final d in remaining)
            _ClassificationRow(driver: d, raceLike: raceLike),
      ],
    );
  }
}

class _ClassificationRow extends StatelessWidget {
  const _ClassificationRow({required this.driver, required this.raceLike});

  final LiveDriverPosition driver;
  final bool raceLike;

  @override
  Widget build(BuildContext context) {
    final isTopThree = driver.position <= 3;
    final podium = livePodiumColors(driver.position);
    final gap = driver.time(raceLike: raceLike);

    return Container(
      decoration: BoxDecoration(
        color: isTopThree ? const Color(0x09FFFFFF) : null, // white/3.5
        border: const Border(
          top: BorderSide(color: Color(0x0DFFFFFF)),
        ), // white/5
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTopThree ? 9 : 8,
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: podium.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${driver.position}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: podium.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: liveDriverAccent(driver.code),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              driver.code,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                color: isTopThree
                    ? const Color(0xFFE8EDF6)
                    : const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              driver.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: isTopThree
                    ? AppColors.white
                    : const Color(0xFFAAB0CC),
                fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            child: Text(
              gap,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: gap == '—'
                    ? const Color(0xFF5B6178)
                    : (isTopThree
                          ? const Color(0xFFAAB0CC)
                          : const Color(0xFF7880A0)),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 연결이 잠깐 흔들려 마지막 순위표를 유지 중임을 알리는 muted 배지(경고 톤 아님).
class _StaleBadge extends StatelessWidget {
  const _StaleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF), // white/8
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        '업데이트 지연',
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'Pretendard',
          color: Color(0xFF8088A8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ended});

  final bool ended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ended ? const Color(0x1AFFFFFF) : AppColors.red,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ended ? const Color(0xFF7880A0) : AppColors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ended ? liveEndedPanelLabel : 'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: ended ? const Color(0xFFAAB0CC) : AppColors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LapChip extends StatelessWidget {
  const _LapChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF), // white/7
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'Pretendard',
          color: AppColors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LiveClock extends StatelessWidget {
  const _LiveClock({required this.label, required this.ended});

  final String? label;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: ended ? const Color(0xFF7880A0) : AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label!,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Pretendard',
            color: Color(0xFF8088A8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
