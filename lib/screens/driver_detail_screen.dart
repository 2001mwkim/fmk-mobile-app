import 'package:flutter/material.dart';

import '../data/drivers.dart';
import '../data/standing_insights.dart';
import '../data/standing_profiles.dart';
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../models/licensed_image.dart';
import '../models/standing_insight.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/licensed_image_view.dart';
import '../widgets/standing_detail_parts.dart';
import 'race_detail_screen.dart';

class DriverDetailScreen extends StatefulWidget {
  const DriverDetailScreen({
    super.key,
    required this.standing,
    required this.allDrivers,
    this.onOpenTeam,
    this.onOpenDriver,
    this.resultsRepository = const HttpRaceResultsRepository(),
  });

  final DriverStanding standing;
  final List<DriverStanding> allDrivers;
  final VoidCallback? onOpenTeam;
  final ValueChanged<DriverStanding>? onOpenDriver;
  final RaceResultsRepository resultsRepository;

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  SeasonRaceResults? _seasonResults;

  @override
  void initState() {
    super.initState();
    _loadSeasonResults();
  }

  Future<void> _loadSeasonResults() async {
    final results = await widget.resultsRepository.fetchSeasonResults();
    if (!mounted || results == null) return;
    setState(() => _seasonResults = results);
  }

  @override
  Widget build(BuildContext context) {
    final standing = widget.standing;
    final allDrivers = widget.allDrivers;
    final onOpenTeam = widget.onOpenTeam;
    final onOpenDriver = widget.onOpenDriver;
    final raceResults = _seasonResults?.raceResultsByRaceId;
    final championshipResults = _seasonResults?.championshipResultsByRaceId;
    final code = driverCodeByNameKo[standing.driverKo] ?? 'DRV';
    final profile = driverProfilesByCode[code];
    final accent = liveDriverAccent(code);
    final summary = driverSeasonSummary(
      standing.driverKo,
      resultsByRaceId: raceResults,
    );
    final recent = recentDriverResults(
      standing.driverKo,
      resultsByRaceId: raceResults,
    );
    final teammate = _teammate();
    final leader = allDrivers.isEmpty ? standing : allDrivers.first;
    final gap = leader.points - standing.points;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(context),
          children: [
            const DetailBackButton(),
            const SizedBox(height: 14),
            Text(
              '드라이버 상세 · 2026 SEASON',
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            _DriverHero(
              standing: standing,
              code: code,
              nationality: profile?.nationalityKo ?? '—',
              image: profile?.image,
              accent: accent,
              gapToLeader: gap,
              onOpenTeam: onOpenTeam,
            ),
            const SizedBox(height: 12),
            AppCard(
              child: SummaryMetrics(summary: summary, accent: accent),
            ),
            const SizedBox(height: 12),
            StandingTrendCard(
              points: driverStandingTrend(
                standing.driverKo,
                resultsByRaceId: championshipResults,
              ),
              color: accent,
            ),
            if (teammate != null) ...[
              const SizedBox(height: 12),
              _TeammateCard(
                driver: standing,
                teammate: teammate,
                accent: accent,
                onTap: onOpenDriver == null
                    ? null
                    : () => onOpenDriver(teammate),
              ),
            ],
            const SizedBox(height: 12),
            _RecentResultsCard(results: recent, accent: accent),
          ],
        ),
      ),
    );
  }

  DriverStanding? _teammate() {
    final candidates = widget.allDrivers.where(
      (driver) =>
          driver.teamKo == widget.standing.teamKo &&
          driver.driverKo != widget.standing.driverKo,
    );
    return candidates.isEmpty ? null : candidates.first;
  }
}

class _DriverHero extends StatelessWidget {
  const _DriverHero({
    required this.standing,
    required this.code,
    required this.nationality,
    required this.image,
    required this.accent,
    required this.gapToLeader,
    required this.onOpenTeam,
  });

  final DriverStanding standing;
  final String code;
  final String nationality;
  final LicensedImage? image;
  final Color accent;
  final num gapToLeader;
  final VoidCallback? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), AppColors.card],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        borderRadius: AppRadius.largeBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    standing.driverKo,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    standing.driverEn,
                    style: const TextStyle(
                      color: AppColors.nameMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _HeroPill(label: 'P${standing.position}', color: accent),
                      _HeroPill(label: '${standing.points} PTS'),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    standing.position == 1
                        ? '챔피언십 리더'
                        : '선두와 ${_formatPoints(gapToLeader)} PTS 차이',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onOpenTeam,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: getTeamColor(standing.teamKo),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              '${standing.teamKo} · $nationality',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slate300,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onOpenTeam != null) ...[
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: LicensedImageView(
              image: image,
              aspectRatio: 4 / 5,
              semanticLabel: '${standing.driverKo} 드라이버 사진',
              fallbackIcon: Icons.person_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.slate300;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TeammateCard extends StatelessWidget {
  const _TeammateCard({
    required this.driver,
    required this.teammate,
    required this.accent,
    required this.onTap,
  });

  final DriverStanding driver;
  final DriverStanding teammate;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DetailSectionTitle('팀메이트 비교'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _comparisonSide(driver, true)),
              Container(width: 1, height: 56, color: AppColors.rowBorder),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: AppRadius.smallBorder,
                  child: _comparisonSide(teammate, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonSide(DriverStanding value, bool selected) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.driverKo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? accent : AppColors.slate300,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'P${value.position}  ·  ${value.points} PTS',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _RecentResultsCard extends StatelessWidget {
  const _RecentResultsCard({required this.results, required this.accent});

  final List<DriverRaceForm> results;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: DetailSectionTitle('최근 5경기'),
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
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.rowBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          form.result.positionLabel == 'DNF'
                              ? 'DNF'
                              : 'P${form.result.position}',
                          style: TextStyle(
                            color: form.result.positionLabel == 'DNF'
                                ? AppColors.redSoft
                                : accent,
                            fontSize: form.result.positionLabel == 'DNF'
                                ? 8
                                : 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              form.race.nameKo,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'R${form.race.round} · ${form.result.points} PTS',
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
                        color: AppColors.textEnded,
                        size: 18,
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

String _formatPoints(num points) =>
    points == points.roundToDouble() ? points.toInt().toString() : '$points';
