import 'package:flutter/material.dart';

import '../data/driver_bios.dart';
import '../data/drivers.dart';
import '../data/race_results.dart';
import '../data/standing_insights.dart';
import '../data/standing_profiles.dart';
import '../data/team_colors.dart';
import '../models/race_result.dart';
import '../models/standing.dart';
import '../models/standing_insight.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/flag_icon.dart';
import '../widgets/glass.dart';
import '../widgets/standing_detail_parts.dart';
import 'race_detail_screen.dart';

/// 드라이버 상세(2026-10 재설계).
/// [사진/팀 색 헤더 → 성적 한 줄 → 시즌 포인트 상세 → 팀메이트 맞대결(포인트·
///  레이스·퀄리) → 프로필 → 시즌 전체 결과]
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
    // 서버 응답 전·실패 시엔 번들 정적 레이스 결과로 그린다(퀄리는 없음).
    final raceResults =
        _seasonResults?.raceResultsByRaceId ?? raceResultsByRaceId;
    final championshipResults =
        _seasonResults?.championshipResultsByRaceId ?? raceResultsByRaceId;
    final qualifyingResults =
        _seasonResults?.qualifyingResultsByRaceId ?? const {};
    final code = driverCodeByNameKo[standing.driverKo] ?? 'DRV';
    final profile = driverProfilesByCode[code];
    final accent = liveDriverAccent(code);
    final teammate = _teammate();
    final leader = widget.allDrivers.isEmpty
        ? standing
        : widget.allDrivers.first;
    final gap = leader.points - standing.points;

    return DetailPageScaffold(
      hero: DetailHero(
        accent: accent,
        image: profile?.image,
        imageLabel: '${standing.driverKo} 드라이버 사진',
        fallbackMark: code,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _DriverIdentity(
                standing: standing,
                code: code,
                nationality: profile?.nationalityKo,
                onOpenTeam: widget.onOpenTeam,
              ),
            ),
            const SizedBox(width: 12),
            DetailRankBlock(
              position: standing.position,
              points: standing.points,
              note: standing.position == 1
                  ? '챔피언십 리더'
                  : '선두와 ${formatDetailPoints(gap)} PTS',
            ),
          ],
        ),
      ),
      children: [
        DetailStatStrip(
          summary: driverSeasonSummary(
            standing.driverKo,
            resultsByRaceId: raceResults,
          ),
        ),
        DetailSection(
          title: '시즌 포인트',
          child: SeasonPointsCard(
            totalPoints: standing.points,
            color: accent,
            breakdown: driverPointsBreakdown(
              standing.driverKo,
              raceResults: raceResults,
              championshipResults: championshipResults,
              qualifyingResults: qualifyingResults,
            ),
          ),
        ),
        if (teammate != null)
          DetailSection(
            title: '팀메이트 맞대결',
            child: _TeammateHeadToHead(
              driver: standing,
              teammate: teammate,
              accent: accent,
              raceResults: raceResults,
              qualifyingResults: qualifyingResults,
              onOpenTeammate: widget.onOpenDriver == null
                  ? null
                  : () => widget.onOpenDriver!(teammate),
            ),
          ),
        if (_profileRows(code, profile?.nationalityKo) case final rows
            when rows.isNotEmpty)
          DetailSection(title: '프로필', child: DetailInfoCard(rows: rows)),
        DetailSection(
          title: '시즌 결과',
          child: _SeasonResultsList(
            forms: recentDriverResults(
              standing.driverKo,
              limit: 99,
              resultsByRaceId: raceResults,
            ),
          ),
        ),
      ],
    );
  }

  /// 프로필 행 — 데이터가 없는 항목은 뺀다(빈 값 '—' 줄을 만들지 않는다).
  List<(String, String)> _profileRows(String code, String? nationality) {
    final bio = driverBiosByCode[code];
    return [
      if (bio != null)
        ('생년월일', formatBirthDateKo(bio.birthDate, DateTime.now())),
      if (bio != null) ('출생지', bio.birthPlaceKo),
      if (nationality != null) ('국적', nationality),
      if (bio != null) ('차량 번호', '${bio.number}'),
      if (bio != null) ('F1 데뷔', '${bio.debutYear}년'),
      if (bio != null && bio.championships > 0)
        ('월드 챔피언', '${bio.championships}회'),
    ];
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

/// 헤더 왼쪽 아래: "ANT · 이탈리아" / 이름 / 팀(탭하면 팀 상세).
class _DriverIdentity extends StatelessWidget {
  const _DriverIdentity({
    required this.standing,
    required this.code,
    required this.nationality,
    required this.onOpenTeam,
  });

  final DriverStanding standing;
  final String code;
  final String? nationality;
  final VoidCallback? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final white = AppColors.pureWhite;
    final team = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: getTeamColor(standing.teamKo),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            standing.teamKo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(color: white),
          ),
        ),
        if (onOpenTeam != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: white.withValues(alpha: 0.7),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nationality == null ? code : '$code · $nationality',
          style: AppType.subhead.copyWith(color: white.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 2),
        Text(
          standing.driverKo,
          maxLines: 2,
          style: AppType.largeTitle.copyWith(color: white),
        ),
        const SizedBox(height: 6),
        if (onOpenTeam == null)
          team
        else
          AppPressable(onTap: onOpenTeam, child: team),
      ],
    );
  }
}

/// 팀메이트 맞대결 카드. 포인트·레이스는 늘 보이고, 퀄리는 서버 세션 결과가
/// 있을 때만(번들 정적 데이터엔 퀄리가 없다).
class _TeammateHeadToHead extends StatelessWidget {
  const _TeammateHeadToHead({
    required this.driver,
    required this.teammate,
    required this.accent,
    required this.raceResults,
    required this.qualifyingResults,
    required this.onOpenTeammate,
  });

  final DriverStanding driver;
  final DriverStanding teammate;
  final Color accent;
  final Map<String, List<RaceResultEntry>> raceResults;
  final Map<String, List<RaceResultEntry>> qualifyingResults;
  final VoidCallback? onOpenTeammate;

  @override
  Widget build(BuildContext context) {
    final race = headToHead(
      driver.driverKo,
      teammate.driverKo,
      resultsByRaceId: raceResults,
    );
    final qualifying = headToHead(
      driver.driverKo,
      teammate.driverKo,
      resultsByRaceId: qualifyingResults,
    );
    final rivalName = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            teammate.driverKo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppType.headline.copyWith(color: AppColors.textMuted),
          ),
        ),
        if (onOpenTeammate != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textEnded,
          ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  driver.driverKo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: AppColors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: onOpenTeammate == null
                      ? rivalName
                      : AppPressable(
                          key: ValueKey('teammate-${teammate.driverKo}'),
                          onTap: onOpenTeammate,
                          child: rivalName,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          HeadToHeadRow(
            label: '포인트',
            left: driver.points,
            right: teammate.points,
            leftText: formatDetailPoints(driver.points),
            rightText: formatDetailPoints(teammate.points),
            leftColor: accent,
          ),
          if (race.total > 0)
            HeadToHeadRow(
              label: '레이스',
              left: race.wins,
              right: race.losses,
              leftColor: accent,
            ),
          if (qualifying.total > 0)
            HeadToHeadRow(
              label: '퀄리파잉',
              left: qualifying.wins,
              right: qualifying.losses,
              leftColor: accent,
            ),
        ],
      ),
    );
  }
}

/// 시즌 전체 결과(최신 라운드부터). 탭하면 GP 상세.
class _SeasonResultsList extends StatelessWidget {
  const _SeasonResultsList({required this.forms});

  final List<DriverRaceForm> forms;

  @override
  Widget build(BuildContext context) {
    if (forms.isEmpty) {
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
          for (final (index, form) in forms.indexed) ...[
            if (index > 0) const DetailRowDivider(indent: 52),
            _ResultRow(form: form),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.form});

  final DriverRaceForm form;

  @override
  Widget build(BuildContext context) {
    final result = form.result;
    final classified = int.tryParse(result.positionLabel) != null;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RaceDetailScreen(race: form.race),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                'R${form.race.round}',
                style: AppType.subhead.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ),
            FlagIcon(countryKo: form.race.countryKo, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                form.race.nameKo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(color: AppColors.white),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text(
                classified ? 'P${result.position}' : result.positionLabel,
                textAlign: TextAlign.right,
                style: AppType.headline.copyWith(
                  color: classified ? AppColors.white : AppColors.textMuted,
                  fontWeight: result.position <= 3 && classified
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '${formatDetailPoints(result.points)} PTS',
                textAlign: TextAlign.right,
                style: AppType.caption.copyWith(
                  color: AppColors.textMuted,
                  fontFeatures: AppType.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
