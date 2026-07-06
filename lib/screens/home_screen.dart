import 'package:flutter/material.dart';

import 'race_detail_screen.dart';
import 'settings_screen.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_live_top_three_card.dart';
import '../widgets/live_session_builder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.nowOverride, this.liveSnapshotOverride});

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: races.isEmpty
          ? const _EmptyHomeContent()
          : _SeasonHomeContent(
              nowOverride: nowOverride,
              liveSnapshotOverride: liveSnapshotOverride,
            ),
    );
  }
}

class _SeasonHomeContent extends StatelessWidget {
  const _SeasonHomeContent({this.nowOverride, this.liveSnapshotOverride});

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;

  /// 스케줄 기준 다음 그랑프리. 다만 라이브 데이터가 레이스의 실제 종료를
  /// 알려주면(스케줄 종료 창보다 일찍 체커기), 그 시점부터 다음 그랑프리로
  /// 넘어간다 — 끝난 레이스를 '진행중'으로 계속 보여주지 않기 위함.
  Race _effectiveNextRace(DateTime now, LiveSessionSnapshot? liveSnapshot) {
    final race = getNextRace(now);
    if (liveSnapshot == null ||
        !liveSnapshotMarksRaceEnded(liveSnapshot, race, now)) {
      return race;
    }
    final weekendEnd = getRaceWeekendEndDate(race);
    if (weekendEnd == null) return race;
    return getNextRace(weekendEnd);
  }

  @override
  Widget build(BuildContext context) {
    final now = nowOverride ?? DateTime.now();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _HomeHeader()),
              const SizedBox(width: 12),
              const _HomeSettingsButton(),
            ],
          ),
          const SizedBox(height: 16),
          // 라이브 Top 3 카드/히어로/주말 일정 모두 같은 스냅샷을 본다.
          LiveSessionBuilder(
            builder: (builderContext, snapshot, isStale) {
              final liveSnapshot = liveSnapshotOverride ?? snapshot;
              final liveStale = liveSnapshotOverride == null && isStale;
              final nextRace = _effectiveNextRace(now, liveSnapshot);
              final nextSession = getNextSession(nextRace, now);
              return Column(
                children: [
                  HomeLiveTopThreeCard(
                    snapshot: liveSnapshot,
                    isStale: liveStale,
                    now: now,
                    onTap: () =>
                        _openLiveRace(builderContext, liveSnapshot?.raceId),
                  ),
                  const SizedBox(height: 12),
                  // 다음 그랑프리 히어로 — 다음 세션 정보를 내부에 포함
                  _NextRaceCard(
                    race: nextRace,
                    session: nextSession,
                    now: now,
                    liveSnapshot: liveSnapshot,
                  ),
                  const SizedBox(height: 12),
                  _WeekendScheduleCard(race: nextRace, now: now),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2026 시즌',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '다가오는 그랑프리와 세션을 확인하세요.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _HomeSettingsButton extends StatelessWidget {
  const _HomeSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        },
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.settings_outlined,
            size: 20,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({
    required this.race,
    required this.session,
    required this.now,
    required this.liveSnapshot,
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;
  final LiveSessionSnapshot? liveSnapshot;

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race, now);
    // 웹 hero: 진행중이면 "진행중", 그 외에는 "다음 그랑프리"(취소는 별도 표기).
    final statusLabel = race.isCancelled
        ? '취소'
        : status == RaceStatus.inProgress
        ? '진행중'
        : '다음 그랑프리';

    return HeroCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppChip(label: statusLabel, variant: AppChipVariant.red),
              const SizedBox(width: 6),
              AppChip(label: 'R${race.round}', variant: AppChipVariant.mono),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            race.nameKo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${race.circuitKo} · ${race.cityKo}, ${race.countryKo}',
            // 웹 hero 서브텍스트 색 (#8088a8)
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8088A8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // 다음/진행 중/최근 세션 정보를 히어로 내부 박스로 표시(웹 hero 의 세션 박스)
          _HeroSessionBox(
            race: race,
            session: session,
            now: now,
            liveSnapshot: liveSnapshot,
          ),
        ],
      ),
    );
  }
}

class _HeroSessionBox extends StatelessWidget {
  const _HeroSessionBox({
    required this.race,
    required this.session,
    required this.now,
    required this.liveSnapshot,
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;
  final LiveSessionSnapshot? liveSnapshot;

  @override
  Widget build(BuildContext context) {
    final s = session;
    // 세션 박스는 '진행중인 세션' 또는 '다음 세션'만 보여준다. 종료된 세션
    // 결과는 라이브 카드/상세 패널이 담당하므로, 스냅샷이 ended 상태면
    // 아래 스케줄 기반 '다음 세션' 표시로 넘어간다.
    final snapshot = _matchingDisplayableSnapshot(liveSnapshot, race, now);
    if (snapshot != null && isLiveSnapshotSessionActive(snapshot, now)) {
      final mappedSession = liveRaceSessionForSnapshot(snapshot, race) ?? s;

      return _sessionBox(
        label: '진행중인 세션',
        accent: AppColors.redSoft,
        sessionTitle: _snapshotSessionTitle(snapshot, mappedSession),
        meta: snapshot.updatedAtLabel ?? 'LIVE',
        value: _liveValue(snapshot),
        valueColor: AppColors.redSoft,
        badgeLabel: 'LIVE',
        badgeVariant: AppChipVariant.red,
        isLive: true,
      );
    }

    if (s == null) {
      return _box(
        child: Text(
          race.cancelNote ?? '세션 정보가 아직 준비되지 않았습니다.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final status = getSessionStatus(race, s, now);
    final isLive = status == SessionStatus.live;
    final raceEnded = getRaceStatus(race, now) == RaceStatus.ended;
    final label = isLive
        ? '진행중인 세션'
        : raceEnded
        ? '최근 세션'
        : '다음 세션';
    final accent = isLive ? AppColors.redSoft : AppColors.blueSoft;

    return _sessionBox(
      label: label,
      accent: accent,
      sessionTitle: s.fullLabel,
      meta: s.date,
      value: isLive ? 'LIVE' : s.time,
      valueColor: isLive ? AppColors.redSoft : AppColors.white,
      badgeLabel: isLive ? 'LIVE' : null,
      badgeVariant: AppChipVariant.red,
      isLive: isLive,
    );
  }

  Widget _sessionBox({
    required String label,
    required Color accent,
    required String sessionTitle,
    required String meta,
    required String value,
    required Color valueColor,
    required String? badgeLabel,
    required AppChipVariant badgeVariant,
    required bool isLive,
  }) {
    return _box(
      isLive: isLive,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(width: 8),
                      AppChip(label: badgeLabel, variant: badgeVariant),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF7880A0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Pretendard',
                  height: 1.1,
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child, bool isLive = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isLive ? null : const Color(0x40000000), // black/25
        gradient: isLive
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1AEF4444), Color(0x40000000)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLive ? const Color(0x66EF4444) : const Color(0x12FFFFFF),
        ),
      ),
      child: child,
    );
  }
}

LiveSessionSnapshot? _matchingDisplayableSnapshot(
  LiveSessionSnapshot? snapshot,
  Race race,
  DateTime now,
) {
  if (snapshot == null || !isLiveSnapshotDisplayable(snapshot, now)) {
    return null;
  }
  return snapshot.raceId == race.id ? snapshot : null;
}

String _snapshotSessionTitle(
  LiveSessionSnapshot snapshot,
  RaceSession? mappedSession,
) {
  // 스냅샷의 영문 세션 이름(예: 'Sprint', 'Race')을 한글로 변환해 우선 사용한다.
  final label = liveSessionLabelKo(snapshot.sessionName, snapshot.sessionType);
  if (label != '세션') return label;

  // 스냅샷에 세션 정보가 없을 때만 스케줄에서 매핑된 한글 라벨로 보완한다.
  final mapped = mappedSession?.fullLabel.trim();
  return (mapped != null && mapped.isNotEmpty) ? mapped : '세션';
}

String _liveValue(LiveSessionSnapshot snapshot) {
  final currentLap = snapshot.currentLap;
  final totalLaps = snapshot.totalLaps;
  if (currentLap != null && totalLaps != null) {
    return '$currentLap / $totalLaps LAP';
  }
  return 'LIVE';
}

class _WeekendScheduleCard extends StatelessWidget {
  const _WeekendScheduleCard({required this.race, required this.now});

  final Race race;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Expanded(child: _SectionHeader(label: '이번 주말 일정')),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 15,
                    color: AppColors.red,
                  ),
                ],
              ),
            ),
            if (race.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  race.cancelNote ?? '세션 일정이 없습니다.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              )
            else
              ...race.sessions.map(
                (session) =>
                    _WeekendSessionRow(race: race, session: session, now: now),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekendSessionRow extends StatelessWidget {
  const _WeekendSessionRow({
    required this.race,
    required this.session,
    required this.now,
  });

  final Race race;
  final RaceSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = getSessionStatus(race, session, now);
    // 강조는 진행중(라이브) 세션에만 적용 — 레이스 상시 강조는 다음/진행중
    // 세션 강조와 겹쳐 혼란을 줘서 제거했다.
    final isLive = status == SessionStatus.live;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: isLive ? AppColors.red.withValues(alpha: 0.08) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isLive ? AppColors.red : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    session.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14.5,
                      height: 1.2,
                      color: isLive ? AppColors.red : AppColors.white,
                      fontWeight: isLive ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                if (isLive) ...[
                  const SizedBox(width: 8),
                  const AppChip(label: 'LIVE', variant: AppChipVariant.red),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${session.date} / ${session.time}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13.5,
              height: 1.2,
              color: isLive ? AppColors.white : AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeContent extends StatelessWidget {
  const _EmptyHomeContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: _HomeSettingsButton(),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '시즌 데이터가 없습니다.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '그랑프리 일정 데이터가 준비되면 홈 화면에 표시됩니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.red,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// 라이브 카드 탭 → raceId 로 Race 를 찾아 상세로 이동. 못 찾으면 SnackBar 안내.
void _openLiveRace(BuildContext context, String? raceId) {
  final race = getRaceById(raceId);
  if (race == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('해당 그랑프리 정보를 찾을 수 없습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)));
}
