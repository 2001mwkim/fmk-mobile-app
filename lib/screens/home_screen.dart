import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'race_detail_screen.dart';
import 'settings_screen.dart';
import '../data/races.dart';
import '../models/race.dart';
import '../models/race_session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/hero_card.dart';

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
    final completedCount = races
        .where((race) => getRaceStatus(race, now) == RaceStatus.ended)
        .length;
    final cancelledCount = races.where((race) => race.isCancelled).length;
    final activeCount = races
        .where((race) => getRaceStatus(race, now) == RaceStatus.inProgress)
        .length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
          const SizedBox(height: 16),
          _NextRaceCard(race: nextRace, now: now),
          const SizedBox(height: 12),
          _NextSessionCard(race: nextRace, session: nextSession),
          const SizedBox(height: 12),
          _WeekendScheduleCard(race: nextRace, now: now),
          const SizedBox(height: 12),
          _SeasonSummaryCard(
            completedCount: completedCount,
            activeCount: activeCount,
            cancelledCount: cancelledCount,
            totalCount: races.length,
          ),
          const SizedBox(height: 12),
          _CalendarLinkCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NextRaceCard extends StatelessWidget {
  const _NextRaceCard({required this.race, required this.now});

  final Race race;
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
          const SizedBox(height: 14),
          _InfoLine(
            icon: Icons.calendar_today_outlined,
            text: _formatDateRange(race.startDate, race.endDate),
          ),
        ],
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard({required this.race, required this.session});

  final Race race;
  final RaceSession? session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: '다음 세션'),
          const SizedBox(height: 12),
          if (session == null) ...[
            Text(
              '세션 일정이 없습니다.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              race.cancelNote ?? '이 그랑프리의 세션 정보가 아직 준비되지 않았습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ] else ...[
            Text(
              session!.fullLabel,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _InfoLine(
              icon: Icons.event_available_outlined,
              text: session!.fullDateTime,
            ),
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.schedule_outlined, text: session!.time),
          ],
        ],
      ),
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

class _SeasonSummaryCard extends StatelessWidget {
  const _SeasonSummaryCard({
    required this.completedCount,
    required this.activeCount,
    required this.cancelledCount,
    required this.totalCount,
  });

  final int completedCount;
  final int activeCount;
  final int cancelledCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final upcomingCount = totalCount - completedCount - activeCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: '시즌 진행 상황'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.black,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: '종료', value: '$completedCount'),
              ),
              Expanded(
                child: _SummaryMetric(label: '진행중', value: '$activeCount'),
              ),
              Expanded(
                child: _SummaryMetric(label: '예정', value: '$upcomingCount'),
              ),
            ],
          ),
          if (cancelledCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '취소된 그랑프리 $cancelledCount개 포함',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarLinkCard extends StatelessWidget {
  const _CalendarLinkCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '전체 일정 보기',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '24개 그랑프리 캘린더',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.red),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

String _formatDateRange(String startDate, String endDate) {
  final start = DateTime.parse(startDate);
  final end = DateTime.parse(endDate);

  if (start.year == end.year && start.month == end.month) {
    return '${start.year}.${_twoDigits(start.month)}.${_twoDigits(start.day)} - ${_twoDigits(end.day)}';
  }

  if (start.year == end.year) {
    return '${start.year}.${_twoDigits(start.month)}.${_twoDigits(start.day)} - ${_twoDigits(end.month)}.${_twoDigits(end.day)}';
  }

  return '${start.year}.${_twoDigits(start.month)}.${_twoDigits(start.day)} - ${end.year}.${_twoDigits(end.month)}.${_twoDigits(end.day)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
