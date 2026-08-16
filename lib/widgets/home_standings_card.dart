import 'package:flutter/material.dart';

import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 홈 "챔피언십 순위" 미니 카드. 순위 탭과 같은 데이터(정적 초기값 →
/// 서버 갱신)를 드라이버·컨스트럭터 Top 3 씩 두 열로 보여주고, 탭하면
/// 순위 탭으로 이동한다. 홈은 공간이 좁아 순위 변동(▲▼)은 생략한다
/// (전체 변동은 순위 탭에서 확인).
class HomeStandingsCard extends StatefulWidget {
  const HomeStandingsCard({super.key, this.repository, this.onOpenStandings});

  /// 테스트/개발용 주입 지점. 기본값은 실서버(/api/standings).
  final StandingsRepository? repository;

  /// 순위 탭으로 전환하는 콜백(MainShell 이 연결). 없으면 탭해도 무동작.
  final VoidCallback? onOpenStandings;

  @override
  State<HomeStandingsCard> createState() => _HomeStandingsCardState();
}

class _HomeStandingsCardState extends State<HomeStandingsCard> {
  // 첫 프레임은 번들 정적 순위로 그리고(로딩 화면 없음), 서버 응답이 오면
  // 최신 순위로 교체한다. 서버 실패 시 정적 데이터가 그대로 남는다.
  List<DriverStanding> _drivers = static_standings.driverStandings;
  List<ConstructorStanding> _constructors =
      static_standings.constructorStandings;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repository = widget.repository ?? const HttpStandingsRepository();
    final snapshot = await repository.fetchLatest();
    if (snapshot == null || !mounted) return;
    setState(() {
      _drivers = snapshot.driverStandings;
      _constructors = snapshot.constructorStandings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _drivers.take(3).toList();
    final constructors = _constructors.take(3).toList();
    if (drivers.isEmpty && constructors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenStandings,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '챔피언십 순위',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    '전체 보기',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StandingsColumn(
                      label: '드라이버',
                      rows: [
                        for (final d in drivers)
                          _RowData(
                            position: d.position,
                            teamKo: d.teamKo,
                            title: d.driverKo,
                            points: d.points,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _StandingsColumn(
                      label: '컨스트럭터',
                      rows: [
                        for (final c in constructors)
                          _RowData(
                            position: c.position,
                            teamKo: c.teamKo,
                            title: c.teamKo,
                            points: c.points,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingsColumn extends StatelessWidget {
  const _StandingsColumn({required this.label, required this.rows});

  final String label;
  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final row in rows) _StandingRow(data: row),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.data});

  final _RowData data;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(
      data.teamKo,
    ).withValues(alpha: isLightTeamColor(data.teamKo) ? 0.7 : 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _RankBadge(position: data.position),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatPoints(data.points),
            style: const TextStyle(
              color: AppColors.slate300,
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: spec.background, shape: BoxShape.circle),
      child: Text(
        '$position',
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'Pretendard',
          color: spec.foreground,
          fontWeight: FontWeight.w800,
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
    required this.points,
  });

  final int position;
  final String teamKo;
  final String title;
  final num points;
}

// 웹 getRankColor. P1은 노란색 대신 레드 톤 사용(앱 규칙상 노란색 금지).
// 순위 탭(standings_screen)의 배지와 동일 사양으로 유지한다.
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
      return (background: AppColors.rowBorder, foreground: AppColors.muted);
  }
}

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }
  return points.toString();
}
