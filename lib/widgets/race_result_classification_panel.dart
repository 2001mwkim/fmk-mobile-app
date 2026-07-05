import 'package:flutter/material.dart';

import '../data/team_colors.dart';
import '../models/live_session.dart';
import '../models/race_result.dart';
import '../theme/app_colors.dart';

/// 종료된 그랑프리 상세 페이지의 최종 순위 패널.
///
/// [RaceLiveClassificationPanel]의 시각 언어(상단 3명 강조 + '4위 이하 순위
/// 보기' 확장)를 정적 결과 데이터([RaceResultEntry])에 적용한 위젯이다.
/// 라이브 스냅샷과 달리 네트워크/폴링 없이 앱 내장 데이터만 그린다.
/// [results]가 비어 있으면 렌더하지 않는다(호출부에서 placeholder 처리).
class RaceResultClassificationPanel extends StatefulWidget {
  const RaceResultClassificationPanel({super.key, required this.results});

  final List<RaceResultEntry> results;

  @override
  State<RaceResultClassificationPanel> createState() =>
      _RaceResultClassificationPanelState();
}

class _RaceResultClassificationPanelState
    extends State<RaceResultClassificationPanel> {
  bool _expanded = false;

  static const Color _muted = Color(0xFF7880A0);
  static const Color _faint = Color(0xFF5B6178);
  static const Color _nameMuted = Color(0xFFAAB0CC);
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results.isEmpty) return const SizedBox.shrink();

    final topThree = results.take(3).toList();
    final remaining = results.skip(3).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141019),
        borderRadius: _radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(results.length),
            _columnHeader(),
            for (final entry in topThree) _ResultRow(entry: entry),
            if (remaining.isNotEmpty) _expander(remaining),
          ],
        ),
      ),
    );
  }

  Widget _header(int driverCount) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x08FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '레이스 결과',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$driverCount DRIVERS',
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
    );
  }

  Widget _columnHeader() {
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
      child: const Row(
        children: [
          SizedBox(width: 26, child: Text('POS', style: style)),
          SizedBox(width: 11),
          Expanded(child: Text('DRIVER', style: style)),
          Text('TIME', style: style),
        ],
      ),
    );
  }

  Widget _expander(List<RaceResultEntry> remaining) {
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: _nameMuted,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: _nameMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final entry in remaining) _ResultRow(entry: entry),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.entry});

  final RaceResultEntry entry;

  static const Color _faint = Color(0xFF5B6178);

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.position <= 3;
    final podium = livePodiumColors(entry.position);
    final teamColor = getTeamColor(
      entry.teamKo,
    ).withValues(alpha: isLightTeamColor(entry.teamKo) ? 0.7 : 1.0);
    // 1위는 총 시간, 이후는 갭. DNF/DNS 등은 POS 라벨이 사유를 보여준다.
    final time = (entry.position == 1 ? entry.time : entry.gap) ?? '—';
    final isNumericLabel = int.tryParse(entry.positionLabel) != null;

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
            width: 26,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: podium.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              entry.positionLabel,
              style: TextStyle(
                fontSize: isNumericLabel ? 12 : 8,
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
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.driverKo,
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
                Text(
                  entry.teamKo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _faint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Pretendard',
              color: time == '—'
                  ? _faint
                  : (isTopThree
                        ? const Color(0xFFAAB0CC)
                        : const Color(0xFF7880A0)),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
