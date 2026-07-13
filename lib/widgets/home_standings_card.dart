import 'package:flutter/material.dart';

import '../data/standings.dart' as static_standings;
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import 'app_card.dart';

/// 홈 "챔피언십 TOP 3" 미니 카드. 순위 탭과 같은 데이터(정적 초기값 →
/// 서버 갱신)를 3행만 보여주고, 탭하면 순위 탭으로 이동한다.
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
  List<DriverStanding> _drivers = static_standings.driverStandings;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final repository = widget.repository ?? const HttpStandingsRepository();
    final snapshot = await repository.fetchLatest();
    if (snapshot == null || !mounted) return;
    setState(() => _drivers = snapshot.driverStandings);
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _drivers.take(3).toList();
    if (top3.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenStandings,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '챔피언십 TOP 3',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    '전체 순위',
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
              const SizedBox(height: 6),
              for (final driver in top3) _DriverRow(driver: driver),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driver});

  final DriverStanding driver;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(
      driver.teamKo,
    ).withValues(alpha: isLightTeamColor(driver.teamKo) ? 0.7 : 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${driver.position}',
              style: TextStyle(
                color: driver.position == 1
                    ? AppColors.redSoft
                    : AppColors.slate300,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 22,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              driver.driverKo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _PositionChange(change: driver.positionChange),
          const SizedBox(width: 10),
          Text(
            _formatPoints(driver.points),
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'PTS',
              style: TextStyle(
                color: AppColors.textEnded,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 순위 탭과 같은 표기: ▲초록/▼레드/0은 —, null(정적 폴백)은 미표시.
class _PositionChange extends StatelessWidget {
  const _PositionChange({required this.change});

  final int? change;

  @override
  Widget build(BuildContext context) {
    final value = change;
    if (value == null) return const SizedBox.shrink();

    final isUp = value > 0;
    final isDown = value < 0;
    return Text(
      isUp
          ? '▲$value'
          : isDown
          ? '▼${value.abs()}'
          : '—',
      style: TextStyle(
        fontSize: 10,
        color: isUp
            ? AppColors.greenSoft
            : isDown
            ? AppColors.redSoft
            : AppColors.muted,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }
  return points.toString();
}
