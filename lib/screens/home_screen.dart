import 'package:flutter/material.dart';

import 'race_detail_screen.dart';
import 'settings_screen.dart';
import '../data/races.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/hero_card.dart';
import '../widgets/home_live_top_three_card.dart';
import '../widgets/live_session_builder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포매코'),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: races.isEmpty
          ? const _EmptyHomeContent()
          : const _SeasonHomeContent(),
    );
  }
}

class _SeasonHomeContent extends StatelessWidget {
  const _SeasonHomeContent();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nextRace = getNextRace(now);
    final nextSession = getNextSession(nextRace, now);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          // 라이브 Top 3 카드 (실데이터 없으면 렌더되지 않음)
          LiveSessionBuilder(
            builder: (builderContext, snapshot) => HomeLiveTopThreeCard(
              snapshot: snapshot,
              onTap: () => _openLiveRace(builderContext, snapshot?.raceId),
            ),
          ),
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
          const SizedBox(height: 16),
          // 다음 그랑프리 히어로 — 다음 세션 정보를 내부에 포함
          _NextRaceCard(race: nextRace, session: nextSession, now: now),
          const SizedBox(height: 12),
          _WeekendScheduleCard(race: nextRace, now: now),
        ],
      ),
    );
  }
}

class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({
    required this.race,
    required this.session,
    required this.now,
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;

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
          _HeroSessionBox(race: race, session: session, now: now),
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
  });

  final Race race;
  final RaceSession? session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = session;
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
        ? '진행 중인 세션'
        : raceEnded
        ? '최근 세션'
        : '다음 세션';
    final accent = isLive ? AppColors.redSoft : AppColors.blueSoft;

    return _box(
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
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      const AppChip(label: 'LIVE', variant: AppChipVariant.red),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.fullLabel,
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
                s.date,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF7880A0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s.time,
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Pretendard',
                  height: 1.1,
                  color: isLive ? AppColors.redSoft : AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x40000000), // black/25
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x12FFFFFF)), // white/7
      ),
      child: child,
    );
  }
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(label: '이번 주말 일정'),
                        const SizedBox(height: 5),
                        Text(
                          '${race.nameKo} · 한국시간 기준',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
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
    final isRace = session.id == 'race';
    final isLive = status == SessionStatus.live;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: isLive ? AppColors.red.withValues(alpha: 0.08) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isRace || isLive ? AppColors.red : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isRace || isLive ? AppColors.red : AppColors.white,
                    fontWeight: isRace || isLive
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session.fullLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppChip(
                label: _sessionStatusLabel(status),
                variant: _sessionStatusVariant(status),
              ),
              const SizedBox(height: 5),
              Text(
                '${session.date} · ${session.time}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
        child: AppCard(
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
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

AppChipVariant _sessionStatusVariant(SessionStatus status) {
  return switch (status) {
    SessionStatus.live => AppChipVariant.red,
    SessionStatus.upcoming => AppChipVariant.neutral,
    SessionStatus.ended => AppChipVariant.ended,
  };
}

String _sessionStatusLabel(SessionStatus status) {
  return switch (status) {
    SessionStatus.upcoming => '예정',
    SessionStatus.live => '진행중',
    SessionStatus.ended => '종료',
  };
}
