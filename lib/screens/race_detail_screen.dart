import 'package:flutter/material.dart';

import '../data/circuit_info.dart';
import '../data/race_results.dart';
import '../data/races.dart';
import '../models/circuit_info.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/race_session.dart';
import '../theme/app_colors.dart';

class RaceDetailScreen extends StatelessWidget {
  const RaceDetailScreen({super.key, required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race);
    final circuitInfo = getCircuitInfo(race.id);
    final top3 = getRaceStatus(race) == RaceStatus.ended && !race.isCancelled
        ? getRaceTop3(race.id)
        : const <RaceResultEntry>[];

    return Scaffold(
      appBar: AppBar(title: Text(race.nameKo)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _HeroCard(race: race, status: status),
            const SizedBox(height: 12),
            _SessionScheduleCard(race: race),
            if (circuitInfo != null) ...[
              const SizedBox(height: 12),
              _CircuitInfoCard(info: circuitInfo),
            ],
            if (top3.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Top3ResultsCard(results: top3),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.race, required this.status});

  final Race race;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaBadge(text: '라운드 ${race.round}'),
              const Spacer(),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            race.nameKo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.place_outlined,
            text: '${race.countryKo} · ${race.cityKo}',
          ),
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.route_outlined, text: race.circuitKo),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.calendar_today_outlined,
            text: _formatDateRange(race.startDate, race.endDate),
          ),
          if (race.hasSprint) ...[
            const SizedBox(height: 12),
            const _SprintBadge(),
          ],
          if (race.isCancelled && race.cancelNote != null) ...[
            const SizedBox(height: 12),
            Text(
              race.cancelNote!,
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

class _SessionScheduleCard extends StatelessWidget {
  const _SessionScheduleCard({required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('세션 일정'),
          const SizedBox(height: 12),
          if (race.sessions.isEmpty)
            Text(
              '세션 일정이 없습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            )
          else
            ...race.sessions.map((session) => _SessionRow(session: session)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final RaceSession session;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              session.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.fullLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.date} · ${session.time}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitInfoCard extends StatelessWidget {
  const _CircuitInfoCard({required this.info});

  final CircuitInfo info;

  @override
  Widget build(BuildContext context) {
    final metrics = <_MetricData>[
      if (info.lengthKm != null)
        _MetricData('길이', '${_formatNumber(info.lengthKm!)} km'),
      if (info.turns != null) _MetricData('코너 수', '${info.turns}'),
      if (info.laps != null) _MetricData('랩 수', '${info.laps}'),
      if (info.distanceKm != null)
        _MetricData('총 거리', '${_formatNumber(info.distanceKm!)} km'),
      if (info.firstYear != null) _MetricData('첫 개최', '${info.firstYear}'),
    ];

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('서킷 정보'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: metrics
                .map(
                  (metric) =>
                      _MetricTile(label: metric.label, value: metric.value),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _Top3ResultsCard extends StatelessWidget {
  const _Top3ResultsCard({required this.results});

  final List<RaceResultEntry> results;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Top 3 결과'),
          const SizedBox(height: 12),
          for (final result in results) _ResultRow(result: result),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final RaceResultEntry result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.black,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.positionLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.driverKo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.teamKo} · ${result.points}점',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child, this.accent = false});

  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(
          color: accent
              ? AppColors.red.withValues(alpha: 0.7)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SprintBadge extends StatelessWidget {
  const _SprintBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '스프린트 주말',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final String value;
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

String _formatNumber(double value) {
  var text = value.toStringAsFixed(3);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

Color _statusColor(String status) {
  return switch (status) {
    RaceStatus.inProgress || RaceStatus.cancelled => AppColors.red,
    RaceStatus.scheduled => AppColors.white,
    _ => AppColors.textMuted,
  };
}
