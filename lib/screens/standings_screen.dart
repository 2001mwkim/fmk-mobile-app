import 'package:flutter/material.dart';

import '../data/standings.dart';
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';

// 웹 순위 페이지 전용 색.
const Color _muted = Color(0xFF7880A0); // #7880a0
const Color _navMuted = Color(0xFF959BB6); // 비활성 탭 텍스트
const Color _hairline = Color(0x14FFFFFF); // white/8 (알약 보더)
const Color _rowBorder = Color(0x0DFFFFFF); // white/5 (행 구분선)
const Color _track = Color(0x0FFFFFFF); // white/6 (진행 막대 배경)

enum _StandingsTab { drivers, constructors }

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  _StandingsTab _tab = _StandingsTab.drivers;

  @override
  Widget build(BuildContext context) {
    final isDrivers = _tab == _StandingsTab.drivers;

    return Scaffold(
      appBar: AppBar(title: const Text('순위')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 상단 제목/설명
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2026 시즌 기준',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '챔피언십 순위',
                    style: TextStyle(
                      fontSize: 26,
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 드라이버 / 컨스트럭터 알약 토글
            _SegmentedTabs(
              tab: _tab,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(height: 16),
            if (isDrivers)
              _StandingsCard(rows: _driverRows(driverStandings))
            else
              _StandingsCard(rows: _constructorRows(constructorStandings)),
            const SizedBox(height: 16),
            const _DataSourceFooter(),
          ],
        ),
      ),
    );
  }

  List<_RowData> _driverRows(List<DriverStanding> standings) {
    if (standings.isEmpty) return const [];
    final leader = standings.first.points;
    return [
      for (final d in standings)
        _RowData(
          position: d.position,
          teamKo: d.teamKo,
          title: d.driverKo,
          teamLabel: d.teamKo,
          points: d.points,
          leaderPoints: leader,
        ),
    ];
  }

  List<_RowData> _constructorRows(List<ConstructorStanding> standings) {
    if (standings.isEmpty) return const [];
    final leader = standings.first.points;
    return [
      for (final c in standings)
        _RowData(
          position: c.position,
          teamKo: c.teamKo,
          title: c.teamKo,
          teamLabel: null,
          points: c.points,
          leaderPoints: leader,
        ),
    ];
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.tab, required this.onChanged});

  final _StandingsTab tab;
  final ValueChanged<_StandingsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: '드라이버',
              selected: tab == _StandingsTab.drivers,
              onTap: () => onChanged(_StandingsTab.drivers),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: '컨스트럭터',
              selected: tab == _StandingsTab.constructors,
              onTap: () => onChanged(_StandingsTab.constructors),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x66EF4444), // rgba(239,68,68,0.4)
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.white : _navMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({required this.rows});

  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyStandings(message: '순위 데이터가 없습니다.');
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              _StandingRow(data: rows[i], isFirst: i == 0),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.data, required this.isFirst});

  final _RowData data;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(
      data.teamKo,
    ).withValues(alpha: isLightTeamColor(data.teamKo) ? 0.7 : 1.0);
    final pct = data.leaderPoints <= 0
        ? 0.0
        : (data.points / data.leaderPoints).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(top: BorderSide(color: _rowBorder)),
      ),
      child: Row(
        children: [
          _RankBadge(position: data.position),
          const SizedBox(width: 12),
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PointsLabel(points: data.points),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (data.teamLabel != null) ...[
                      SizedBox(
                        width: 62,
                        child: Text(
                          data.teamLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _PointsBar(pct: pct, color: teamColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    final spec = _rankColor(position);

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: spec.background, shape: BoxShape.circle),
      child: Text(
        '$position',
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'Pretendard',
          color: spec.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PointsLabel extends StatelessWidget {
  const _PointsLabel({required this.points});

  final num points;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatPoints(points),
          style: const TextStyle(
            fontSize: 18,
            fontFamily: 'Pretendard',
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        const Padding(
          padding: EdgeInsets.only(bottom: 2),
          child: Text(
            'PTS',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textEnded,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PointsBar extends StatelessWidget {
  const _PointsBar({required this.pct, required this.color});

  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: _track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: pct,
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _EmptyStandings extends StatelessWidget {
  const _EmptyStandings({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _DataSourceFooter extends StatelessWidget {
  const _DataSourceFooter();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '데이터 출처: F1DB (CC BY 4.0)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textEnded,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RowData {
  const _RowData({
    required this.position,
    required this.teamKo,
    required this.title,
    required this.teamLabel,
    required this.points,
    required this.leaderPoints,
  });

  final int position;
  final String teamKo;
  final String title;
  final String? teamLabel;
  final num points;
  final num leaderPoints;
}

// 웹 getRankColor. P1은 노란색 대신 레드 톤 사용(앱 규칙상 노란색 금지).
({Color background, Color foreground}) _rankColor(int position) {
  switch (position) {
    case 1:
      return (
        background: const Color(0x26EF4444),
        foreground: AppColors.redSoft,
      );
    case 2:
      return (
        background: const Color(0x2694A3B8), // slate-400/15
        foreground: AppColors.slate300,
      );
    case 3:
      return (
        background: const Color(0x26F97316), // orange-500/15
        foreground: const Color(0xFFFB923C), // orange-400
      );
    default:
      return (background: const Color(0x0DFFFFFF), foreground: _muted);
  }
}

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }

  return points.toString();
}
