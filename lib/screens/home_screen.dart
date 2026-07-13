import 'package:flutter/material.dart';

import 'race_detail_screen.dart';
import 'settings_screen.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../services/standings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_live_top_three_card.dart';
import '../widgets/home_quick_actions_card.dart';
import '../widgets/home_standings_card.dart';
import '../widgets/live_session_builder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.nowOverride,
    this.liveSnapshotOverride,
    this.onOpenStandings,
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;

  /// 순위 탭으로 전환(TOP 3 카드 탭). MainShell 이 연결한다.
  final VoidCallback? onOpenStandings;

  /// TOP 3 카드용 — 테스트/개발 주입 지점.
  final StandingsRepository? standingsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: races.isEmpty
          ? const _EmptyHomeContent()
          : _SeasonHomeContent(
              nowOverride: nowOverride,
              liveSnapshotOverride: liveSnapshotOverride,
              onOpenStandings: onOpenStandings,
              standingsRepository: standingsRepository,
            ),
    );
  }
}

class _SeasonHomeContent extends StatelessWidget {
  const _SeasonHomeContent({
    this.nowOverride,
    this.liveSnapshotOverride,
    this.onOpenStandings,
    this.standingsRepository,
  });

  final DateTime? nowOverride;
  final LiveSessionSnapshot? liveSnapshotOverride;
  final VoidCallback? onOpenStandings;
  final StandingsRepository? standingsRepository;

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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  // 주말 일정은 히어로 카드에 통합됨(별도 카드 제거).
                  // 챔피언십 TOP 3 — 순위 탭과 같은 데이터의 미리보기.
                  HomeStandingsCard(
                    repository: standingsRepository,
                    onOpenStandings: onOpenStandings,
                  ),
                  // 빠른 설정: 알림 + 위젯(메인 기능) 진입점.
                  const SizedBox(height: 12),
                  const HomeQuickActionsCard(),
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
    // 리디자인(home_screen_2a): 서브카피 없이 타이틀만 크게(26/900).
    return const Text(
      '2026 시즌',
      style: TextStyle(
        fontSize: 26,
        height: 1,
        color: AppColors.white,
        fontWeight: FontWeight.w900,
      ),
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

    // 리디자인(home_screen_2a): 별도 '이번 주말 일정' 카드를 없애고 히어로가
    // [뱃지 → 그랑프리명 → 서킷 → 다음 세션 박스 → 나머지 세션 리스트 → KST]
    // 를 한 카드로 담는다. 세션 박스에 나온 세션은 리스트에서 제외(중복 방지).
    final boxedSession = session;
    final listSessions = race.sessions
        .where((s) => s.id != boxedSession?.id)
        .toList();

    return HeroCard(
      // 다음 GP 서킷 아웃라인을 배경 장식으로(에셋 없으면 자동 미표시).
      circuitAssetPath: 'assets/circuits/${race.id}.svg',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RaceDetailScreen(race: race)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 리디자인: 'R12' 라운드 뱃지는 제거하고 상태 뱃지만 남긴다.
          Row(
            children: [
              AppChip(label: statusLabel, variant: AppChipVariant.red),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            race.nameKo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              height: 1.15,
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
              color: AppColors.heroSub,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          // 다음/진행 중/최근 세션 정보를 히어로 내부 박스로 표시(웹 hero 의 세션 박스)
          _HeroSessionBox(
            race: race,
            session: session,
            now: now,
            liveSnapshot: liveSnapshot,
          ),
          // 나머지 주말 세션 리스트 (박스 없는 플레인 행 — 기존 주말 일정 카드 대체)
          if (listSessions.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final s in listSessions)
              _HeroScheduleRow(race: race, session: s, now: now),
          ],
        ],
      ),
    );
  }
}

/// 히어로 내부 주말 세션 한 줄: 상태 도트 · 세션명 · 날짜/시간.
/// 상태별 표기(디자인 home_screen_2a):
/// - 완료: 체크 아이콘 + 흐린 텍스트
/// - 레이스(미완료): 레드 도트 + 흰색 강조
/// - 예정: 회색 도트 + 목록 톤 텍스트
class _HeroScheduleRow extends StatelessWidget {
  const _HeroScheduleRow({
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
    final isDone = status == SessionStatus.ended;
    final isRace = session.id == 'race' && !isDone;

    final nameColor = isDone
        ? AppColors.textEnded
        : isRace
        ? AppColors.white
        : AppColors.scheduleText;
    final timeColor = isDone
        ? AppColors.textEnded
        : isRace
        ? AppColors.white
        : AppColors.muted;
    final weight = isRace ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          // 상태 도트: 완료는 체크, 레이스는 레드, 예정은 비활성 톤.
          if (isDone)
            const Icon(Icons.check, size: 11, color: AppColors.textEnded)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isRace ? AppColors.red : AppColors.dotInactive,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              session.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                color: nameColor,
                fontWeight: weight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${session.date} ${session.time}',
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              color: timeColor,
              fontWeight: weight,
            ),
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
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                // 시간/LIVE/랩 카운트 — 라틴 표기라 디스플레이 폰트 적용.
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: kDisplayFontFamily,
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
          color: isLive ? const Color(0x66EF4444) : AppColors.divider,
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
