import 'package:flutter/material.dart';

import '../data/driver_bios.dart';
import '../data/drivers.dart';
import '../data/race_results.dart';
import '../data/standing_insights.dart';
import '../data/standing_profiles.dart';
import '../data/team_colors.dart';
import '../models/standing.dart';
import '../models/standing_insight.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/flag_icon.dart';
import '../widgets/standing_detail_parts.dart';
import 'race_detail_screen.dart';

/// 컨스트럭터 상세(2026-10 재설계).
/// [머신 사진/팀 색 헤더 → 드라이버(분할 기여도 막대 + 행) → 성적 한 줄 →
///  시즌 포인트 상세 → 프로필 → 시즌 결과(라운드마다 두 드라이버)]
class TeamDetailScreen extends StatefulWidget {
  const TeamDetailScreen({
    super.key,
    required this.standing,
    required this.allDrivers,
    this.onOpenDriver,
    this.resultsRepository = const HttpRaceResultsRepository(),
  });

  final ConstructorStanding standing;
  final List<DriverStanding> allDrivers;
  final ValueChanged<DriverStanding>? onOpenDriver;
  final RaceResultsRepository resultsRepository;

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
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
    final profile = teamProfilesByKo[standing.teamKo];
    final color = getTeamColor(standing.teamKo);
    // 시즌 중 이적이 있었던 팀은 현재 라인업만 보여준다(레드불: 로슨 → 하자르).
    final drivers = widget.allDrivers
        .where((driver) => driver.teamKo == standing.teamKo)
        .where(
          (driver) =>
              standing.teamKo != '레드불 레이싱' ||
              driver.driverKo == '막스 베르스타펜' ||
              driver.driverKo == '아이작 하자르',
        )
        .toList(growable: false);
    final raceResults =
        _seasonResults?.raceResultsByRaceId ?? raceResultsByRaceId;
    final championshipResults =
        _seasonResults?.championshipResultsByRaceId ?? raceResultsByRaceId;
    final qualifyingResults =
        _seasonResults?.qualifyingResultsByRaceId ?? const {};
    final bio = teamBiosByKo[standing.teamKo];
    final profileRows = <(String, String)>[
      if (profile != null) ('국적', profile.countryKo),
      if (profile?.baseKo case final base?) ('본거지', base),
      if (profile != null) ('섀시', profile.carName),
      if (bio != null) ('파워유닛', bio.powerUnitKo),
      if (bio != null && bio.championships > 0)
        ('컨스트럭터 챔피언', '${bio.championships}회'),
    ];
    final leader = _leaderPoints();
    final gap = leader - standing.points;
    final info = [
      profile?.countryKo,
      profile?.carName,
      profile?.baseKo,
    ].whereType<String>().join(' · ');

    return DetailPageScaffold(
      hero: DetailHero(
        accent: color,
        image: profile?.image,
        imageLabel: '${standing.teamKo} 2026 머신',
        fallbackMark: standing.teamEn.split(' ').first.toUpperCase(),
        height: 320,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (info.isNotEmpty)
                    Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.subhead.copyWith(
                        color: AppColors.pureWhite.withValues(alpha: 0.75),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    standing.teamKo,
                    maxLines: 2,
                    style: AppType.largeTitle.copyWith(
                      color: AppColors.pureWhite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DetailRankBlock(
              position: standing.position,
              points: standing.points,
              note: standing.position == 1
                  ? '컨스트럭터 선두'
                  : '선두와 ${formatDetailPoints(gap)} PTS',
            ),
          ],
        ),
      ),
      children: [
        _DriversCard(
          drivers: drivers,
          color: color,
          onOpenDriver: widget.onOpenDriver,
        ),
        const SizedBox(height: 12),
        DetailStatStrip(
          summary: teamSeasonSummary(
            standing.teamKo,
            resultsByRaceId: raceResults,
          ),
        ),
        DetailSection(
          title: '시즌 포인트',
          child: SeasonPointsCard(
            totalPoints: standing.points,
            color: color,
            breakdown: teamPointsBreakdown(
              standing.teamKo,
              raceResults: raceResults,
              championshipResults: championshipResults,
              qualifyingResults: qualifyingResults,
            ),
          ),
        ),
        if (profileRows.isNotEmpty)
          DetailSection(
            title: '프로필',
            child: DetailInfoCard(rows: profileRows),
          ),
        DetailSection(
          title: '시즌 결과',
          child: _TeamResultsList(
            rounds: teamSeasonResults(
              standing.teamKo,
              resultsByRaceId: raceResults,
            ),
          ),
        ),
      ],
    );
  }

  /// 컨스트럭터 선두 포인트 — 드라이버 목록에서 팀별로 합산해 구한다(화면이
  /// 컨스트럭터 전체 목록을 받지 않아서).
  num _leaderPoints() {
    final byTeam = <String, num>{};
    for (final driver in widget.allDrivers) {
      byTeam.update(
        driver.teamKo,
        (value) => value + driver.points,
        ifAbsent: () => driver.points,
      );
    }
    if (byTeam.isEmpty) return widget.standing.points;
    final top = byTeam.values.reduce((a, b) => a > b ? a : b);
    return top > widget.standing.points ? top : widget.standing.points;
  }
}

/// 드라이버 두 명: 위에 팀 포인트 기여도 분할 막대, 아래 행(탭 → 드라이버 상세).
class _DriversCard extends StatelessWidget {
  const _DriversCard({
    required this.drivers,
    required this.color,
    required this.onOpenDriver,
  });

  final List<DriverStanding> drivers;
  final Color color;
  final ValueChanged<DriverStanding>? onOpenDriver;

  @override
  Widget build(BuildContext context) {
    if (drivers.isEmpty) {
      return AppCard(
        child: Text(
          '드라이버 정보가 없습니다.',
          style: AppType.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    final sorted = [...drivers]..sort((a, b) => b.points.compareTo(a.points));
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sorted.length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '팀 포인트 기여도',
                    style: AppType.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SplitBar(
                    left: sorted[0].points,
                    right: sorted[1].points,
                    leftColor: color,
                    rightColor: color.withValues(alpha: 0.4),
                    height: 8,
                  ),
                ],
              ),
            ),
          for (final (index, driver) in sorted.indexed) ...[
            if (index > 0) const DetailRowDivider(),
            _DriverRow(
              driver: driver,
              color: index == 0 ? color : color.withValues(alpha: 0.4),
              onTap: onOpenDriver == null ? null : () => onOpenDriver!(driver),
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.driver,
    required this.color,
    required this.onTap,
  });

  final DriverStanding driver;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final code = driverCodeByNameKo[driver.driverKo];
    return InkWell(
      key: ValueKey('team-driver-${driver.driverKo}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            // 이름과 코드를 따로 둬서 이름만 줄임표로 잘린다.
            Flexible(
              child: Text(
                driver.driverKo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: AppColors.white),
              ),
            ),
            if (code != null) ...[
              const SizedBox(width: 6),
              Text(
                code,
                style: AppType.subhead.copyWith(color: AppColors.textMuted),
              ),
            ],
            const Spacer(),
            Text(
              '${driver.position}위',
              style: AppType.subhead.copyWith(
                color: AppColors.textMuted,
                fontFeatures: AppType.tabular,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDetailPoints(driver.points),
              style: AppType.headline.copyWith(
                color: AppColors.white,
                fontFeatures: AppType.tabular,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'PTS',
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textEnded,
              ),
          ],
        ),
      ),
    );
  }
}

/// 라운드마다 한 줄: "R7 🇪🇸 스페인 그랑프리 / RUS P2 · ANT P16 ...... 18 PTS".
class _TeamResultsList extends StatelessWidget {
  const _TeamResultsList({required this.rounds});

  final List<TeamRoundResult> rounds;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return AppCard(
        child: Text(
          '아직 기록된 결과가 없습니다.',
          style: AppType.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, round) in rounds.indexed) ...[
            if (index > 0) const DetailRowDivider(indent: 52),
            _TeamRoundRow(round: round),
          ],
        ],
      ),
    );
  }
}

class _TeamRoundRow extends StatelessWidget {
  const _TeamRoundRow({required this.round});

  final TeamRoundResult round;

  @override
  Widget build(BuildContext context) {
    final finishes = round.entries
        .map((entry) {
          final code = driverCodeByNameKo[entry.driverKo] ?? entry.driverKo;
          final classified = int.tryParse(entry.positionLabel) != null;
          return '$code ${classified ? 'P${entry.position}' : entry.positionLabel}';
        })
        .join(' · ');
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RaceDetailScreen(race: round.race),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                'R${round.race.round}',
                style: AppType.subhead.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FlagIcon(countryKo: round.race.countryKo, size: 13),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          round.race.nameKo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: AppColors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    finishes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.subhead.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatDetailPoints(round.points),
              style: AppType.headline.copyWith(
                color: AppColors.white,
                fontFeatures: AppType.tabular,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'PTS',
              style: AppType.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
