import 'package:flutter/material.dart';

import '../data/team_colors.dart';
import '../models/race_result.dart';
import '../theme/app_colors.dart';
import 'classification_panel_parts.dart';

/// 종료된 그랑프리 상세 페이지의 최종 순위 패널.
///
/// 라이브 순위 패널과 같은 시각 언어(상단 3명 강조 + '4위 이하 순위 보기'
/// 확장)를 정적 결과 데이터([RaceResultEntry])에 적용한 위젯이다. 카드 셸/행/
/// 확장 UI 는 [classification_panel_parts.dart] 의 공용 위젯을 쓴다.
/// 라이브 스냅샷과 달리 네트워크/폴링 없이 앱 내장 데이터만 그린다.
/// [results]가 비어 있으면 렌더하지 않는다(호출부에서 placeholder 처리).
class RaceResultClassificationPanel extends StatelessWidget {
  const RaceResultClassificationPanel({
    super.key,
    required this.results,
    this.statusLabel,
    this.title = '레이스 결과',
    this.showDriverCount = true,
    this.gapBased = true,
  });

  final List<RaceResultEntry> results;

  /// 서버 결과 상태 표기('공식 결과'/'잠정 결과'). null 이면 표시하지 않음
  /// (번들 정적 데이터로 그릴 때).
  final String? statusLabel;
  final String title;
  final bool showDriverCount;

  /// true(레이스/스프린트): 1위 총 시간 + 이후는 갭.
  /// false(연습/퀄리파잉): 순위와 무관하게 각자의 랩타임을 보여준다 —
  /// 갭 규칙을 그대로 쓰면 2위 이하가 전부 '—'가 된다(갭 없음).
  final bool gapBased;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    final topThree = results.take(3).toList();
    final remaining = results.skip(3).toList();

    return ClassificationPanelShell(
      borderColor: AppColors.border,
      children: [
        _header(results.length),
        const ClassificationColumnHeader(timeLabel: 'TIME'),
        for (final entry in topThree) _row(entry),
        if (remaining.isNotEmpty)
          ClassificationExpander(
            accent: AppColors.nameMuted,
            startPosition: remaining.first.position,
            endPosition: remaining.last.position,
            count: remaining.length,
            rows: [for (final entry in remaining) _row(entry)],
          ),
      ],
    );
  }

  Widget _row(RaceResultEntry entry) {
    final teamColor = getTeamColor(
      entry.teamKo,
    ).withValues(alpha: isLightTeamColor(entry.teamKo) ? 0.7 : 1.0);
    // 레이스류: 1위 총 시간 + 이후 갭(DNF/DNS 는 POS 라벨이 사유 표시).
    // 연습/퀄리: 행별 랩타임.
    final time = gapBased
        ? (entry.position == 1 ? entry.time : entry.gap) ?? '—'
        : entry.time ?? entry.gap ?? '—';

    return ClassificationRow(
      position: entry.position,
      positionLabel: entry.positionLabel,
      accentColor: teamColor,
      name: entry.driverKo,
      subtitle: entry.teamKo,
      trailing: time,
    );
  }

  Widget _header(int driverCount) {
    return ClassificationHeaderContainer(
      emphasized: false,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 10),
            Text(
              statusLabel!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.nameMuted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
          if (showDriverCount) ...[
            const SizedBox(width: 10),
            Text(
              '$driverCount DRIVERS',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'Pretendard',
                color: AppColors.faint,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
