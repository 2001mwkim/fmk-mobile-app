import 'package:flutter/material.dart';

import '../data/standing_insights.dart';
import '../data/standing_profiles.dart';
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../models/standing_insight.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/licensed_image_view.dart';
import '../widgets/standing_detail_parts.dart';
import 'race_detail_screen.dart';

class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({
    super.key,
    required this.standing,
    required this.allDrivers,
    this.onOpenDriver,
  });

  final ConstructorStanding standing;
  final List<DriverStanding> allDrivers;
  final ValueChanged<DriverStanding>? onOpenDriver;

  @override
  Widget build(BuildContext context) {
    final profile = teamProfilesByKo[standing.teamKo];
    final color = getTeamColor(standing.teamKo);
    final drivers = allDrivers
        .where((driver) => driver.teamKo == standing.teamKo)
        .toList(growable: false);
    final summary = teamSeasonSummary(standing.teamKo);
    final recent = recentTeamResults(standing.teamKo);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(context),
          children: [
            const DetailBackButton(),
            const SizedBox(height: 14),
            Text(
              '컨스트럭터 상세 · 2026 SEASON',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            LicensedImageView(
              image: profile?.image,
              aspectRatio: 16 / 9,
              semanticLabel: '${standing.teamKo} 2026 머신',
              fallbackIcon: Icons.sports_motorsports_outlined,
            ),
            const SizedBox(height: 10),
            _TeamIdentityCard(
              standing: standing,
              country: profile?.countryKo ?? '—',
              base: profile?.baseKo,
              carName: profile?.carName ?? '—',
              color: color,
            ),
            const SizedBox(height: 12),
            AppCard(child: SummaryMetrics(summary: summary)),
            const SizedBox(height: 12),
            _DriverContributionCard(
              drivers: drivers,
              totalPoints: standing.points,
              color: color,
              onOpenDriver: onOpenDriver,
            ),
            const SizedBox(height: 12),
            StandingTrendCard(
              points: teamStandingTrend(standing.teamKo),
              color: color,
            ),
            const SizedBox(height: 12),
            _TeamRecentResultsCard(results: recent, color: color),
          ],
        ),
      ),
    );
  }
}

class _TeamIdentityCard extends StatelessWidget {
  const _TeamIdentityCard({
    required this.standing,
    required this.country,
    required this.base,
    required this.carName,
    required this.color,
  });

  final ConstructorStanding standing;
  final String country;
  final String? base;
  final String carName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      standing.teamKo,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      standing.teamEn,
                      style: const TextStyle(
                        color: AppColors.nameMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'P${standing.position}',
                    style: TextStyle(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${standing.points} PTS',
                    style: const TextStyle(
                      color: AppColors.slate300,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(icon: Icons.flag_outlined, label: country),
              _InfoChip(icon: Icons.directions_car_outlined, label: carName),
              if (base != null)
                _InfoChip(icon: Icons.location_on_outlined, label: base!),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.tileSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.faintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.slate300,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverContributionCard extends StatelessWidget {
  const _DriverContributionCard({
    required this.drivers,
    required this.totalPoints,
    required this.color,
    required this.onOpenDriver,
  });

  final List<DriverStanding> drivers;
  final num totalPoints;
  final Color color;
  final ValueChanged<DriverStanding>? onOpenDriver;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('드라이버 포인트 기여도'),
          const SizedBox(height: 14),
          if (drivers.isEmpty)
            const Text(
              '드라이버 정보가 없습니다.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            )
          else
            for (final driver in drivers) ...[
              InkWell(
                key: ValueKey('team-driver-${driver.driverKo}'),
                onTap: onOpenDriver == null
                    ? null
                    : () => onOpenDriver!(driver),
                borderRadius: AppRadius.smallBorder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          driver.driverKo,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${driver.points} PTS',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (onOpenDriver != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textEnded,
                        ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: totalPoints == 0
                      ? 0
                      : (driver.points / totalPoints).clamp(0, 1).toDouble(),
                  color: color,
                  backgroundColor: AppColors.rowBorder,
                ),
              ),
              const SizedBox(height: 5),
            ],
        ],
      ),
    );
  }
}

class _TeamRecentResultsCard extends StatelessWidget {
  const _TeamRecentResultsCard({required this.results, required this.color});

  final List<DriverRaceForm> results;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: DetailSectionTitle('최근 팀 결과'),
          ),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '아직 기록된 결과가 없습니다.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            for (final form in results)
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RaceDetailScreen(race: form.race),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.rowBorder)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          form.result.positionLabel == 'DNF'
                              ? 'DNF'
                              : 'P${form.result.position}',
                          style: TextStyle(
                            color: form.result.positionLabel == 'DNF'
                                ? AppColors.redSoft
                                : color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              form.result.driverKo,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${form.race.nameKo} · ${form.result.points} PTS',
                              style: const TextStyle(
                                color: AppColors.textEnded,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textEnded,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
