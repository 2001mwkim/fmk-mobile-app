import 'package:flutter/material.dart';

import '../models/live_session.dart';
import '../theme/app_colors.dart';
import 'classification_panel_parts.dart';

/// 웹 components/live/RaceLiveClassificationPanel.tsx 의 Flutter 이식.
///
/// snapshot 이 없거나 표시 불가/다른 그랑프리/순위 비어있으면 렌더하지 않는다.
/// 실데이터 연결 전에는 [snapshot] 이 null 로 들어와 화면에 노출되지 않는다.
/// 카드 셸/행/확장 UI 는 최종 결과 패널과 공유한다
/// ([classification_panel_parts.dart] 참고).
class RaceLiveClassificationPanel extends StatelessWidget {
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

  static const Color _faint = AppColors.faint;
  static const Color _nameMuted = AppColors.nameMuted;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null ||
        !isLiveSnapshotDisplayable(s, now) ||
        s.raceId != raceId ||
        s.classification.isEmpty) {
      return const SizedBox.shrink();
    }

    final ended = s.isEnded && !isLiveSnapshotSessionActive(s, now);
    final raceLike = s.isRaceOrSprint;
    final topThree = s.classification.take(3).toList();
    final remaining = s.classification.skip(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClassificationPanelShell(
        borderColor: ended ? AppColors.border : const Color(0x66EF4444),
        children: [
          _header(s, ended),
          ClassificationColumnHeader(timeLabel: s.gapColumnLabel),
          for (final d in topThree) _row(d, raceLike),
          if (remaining.isNotEmpty)
            ClassificationExpander(
              accent: ended ? _nameMuted : AppColors.redSoft,
              startPosition: remaining.first.position,
              endPosition: remaining.last.position,
              count: remaining.length,
              rows: [for (final d in remaining) _row(d, raceLike)],
            ),
        ],
      ),
    );
  }

  Widget _row(LiveDriverPosition driver, bool raceLike) {
    return ClassificationRow(
      position: driver.position,
      accentColor: liveDriverAccent(driver.code),
      code: driver.code,
      name: driver.displayName,
      trailing: driver.time(raceLike: raceLike),
    );
  }

  Widget _header(LiveSessionSnapshot s, bool ended) {
    return ClassificationHeaderContainer(
      emphasized: !ended,
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
              if (isStale) ...[
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
          color: AppColors.heroSub,
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
              color: ended ? AppColors.muted : AppColors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ended ? liveEndedPanelLabel : 'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: ended ? AppColors.nameMuted : AppColors.white,
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
        color: AppColors.divider, // white/7
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
            color: ended ? AppColors.muted : AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label!,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Pretendard',
            color: AppColors.heroSub,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
