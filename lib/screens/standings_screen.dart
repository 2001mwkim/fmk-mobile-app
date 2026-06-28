import 'package:flutter/material.dart';

import '../data/standings.dart';
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../theme/app_colors.dart';

class StandingsScreen extends StatelessWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('순위'),
          bottom: const TabBar(
            indicatorColor: AppColors.red,
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.textMuted,
            tabs: [
              Tab(text: '드라이버'),
              Tab(text: '컨스트럭터'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _DriverStandingsList(standings: driverStandings),
              _ConstructorStandingsList(standings: constructorStandings),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverStandingsList extends StatelessWidget {
  const _DriverStandingsList({required this.standings});

  final List<DriverStanding> standings;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const _EmptyStandings(message: '드라이버 순위 데이터가 없습니다.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: standings.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _StandingsHeader(
            title: '드라이버 순위',
            subtitle: '${standings.length}명 · 포인트 기준',
          );
        }

        return _DriverStandingCard(standing: standings[index - 1]);
      },
    );
  }
}

class _ConstructorStandingsList extends StatelessWidget {
  const _ConstructorStandingsList({required this.standings});

  final List<ConstructorStanding> standings;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const _EmptyStandings(message: '컨스트럭터 순위 데이터가 없습니다.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: standings.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _StandingsHeader(
            title: '컨스트럭터 순위',
            subtitle: '${standings.length}팀 · 포인트 기준',
          );
        }

        return _ConstructorStandingCard(standing: standings[index - 1]);
      },
    );
  }
}

class _StandingsHeader extends StatelessWidget {
  const _StandingsHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DriverStandingCard extends StatelessWidget {
  const _DriverStandingCard({required this.standing});

  final DriverStanding standing;

  @override
  Widget build(BuildContext context) {
    return _StandingCard(
      position: standing.position,
      teamKo: standing.teamKo,
      title: standing.driverKo,
      subtitle: standing.teamKo,
      points: standing.points,
    );
  }
}

class _ConstructorStandingCard extends StatelessWidget {
  const _ConstructorStandingCard({required this.standing});

  final ConstructorStanding standing;

  @override
  Widget build(BuildContext context) {
    return _StandingCard(
      position: standing.position,
      teamKo: standing.teamKo,
      title: standing.teamKo,
      subtitle: standing.teamEn,
      points: standing.points,
    );
  }
}

class _StandingCard extends StatelessWidget {
  const _StandingCard({
    required this.position,
    required this.teamKo,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final int position;
  final String teamKo;
  final String title;
  final String subtitle;
  final num points;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(teamKo);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _PositionBadge(position: position),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: teamColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _PointsBadge(points: points),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionBadge extends StatelessWidget {
  const _PositionBadge({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: position <= 3
            ? AppColors.red.withValues(alpha: 0.14)
            : AppColors.black,
        border: Border.all(
          color: position <= 3
              ? AppColors.red.withValues(alpha: 0.55)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$position',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: position <= 3 ? AppColors.red : AppColors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final num points;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatPoints(points),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '포인트',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _EmptyStandings extends StatelessWidget {
  const _EmptyStandings({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ),
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
