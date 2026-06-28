import 'package:flutter/material.dart';

import '../data/races.dart';
import '../models/race.dart';
import 'race_detail_screen.dart';
import '../theme/app_colors.dart';

enum _CalendarFilter {
  all('전체'),
  scheduled('예정'),
  inProgress('진행중'),
  ended('종료');

  const _CalendarFilter(this.label);

  final String label;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _CalendarFilter _selectedFilter = _CalendarFilter.all;

  @override
  Widget build(BuildContext context) {
    final visibleRaces = _filteredRaces(_selectedFilter);

    return Scaffold(
      appBar: AppBar(title: const Text('일정')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: visibleRaces.isEmpty ? 3 : visibleRaces.length + 2,
          separatorBuilder: (_, index) => index <= 1
              ? const SizedBox(height: 12)
              : const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _CalendarHeader();
            }

            if (index == 1) {
              return _CalendarFilterTabs(
                selectedFilter: _selectedFilter,
                onChanged: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              );
            }

            if (visibleRaces.isEmpty) {
              return _EmptyCalendarFilter(filter: _selectedFilter);
            }

            final race = visibleRaces[index - 2];
            return _RaceCard(
              race: race,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RaceDetailScreen(race: race),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Race> _filteredRaces(_CalendarFilter filter) {
    final sortedRaces = [...races];

    if (filter == _CalendarFilter.all) {
      sortedRaces.sort((a, b) {
        final groupCompare = _calendarGroup(a).compareTo(_calendarGroup(b));
        if (groupCompare != 0) return groupCompare;
        return a.round.compareTo(b.round);
      });
      return sortedRaces;
    }

    return sortedRaces.where((race) {
      final status = getRaceStatus(race);
      return switch (filter) {
        _CalendarFilter.scheduled => status == RaceStatus.scheduled,
        _CalendarFilter.inProgress => status == RaceStatus.inProgress,
        _CalendarFilter.ended => status == RaceStatus.ended,
        _CalendarFilter.all => true,
      };
    }).toList();
  }
}

int _calendarGroup(Race race) {
  final status = getRaceStatus(race);
  return status == RaceStatus.ended ? 1 : 0;
}

class _CalendarFilterTabs extends StatelessWidget {
  const _CalendarFilterTabs({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _CalendarFilter selectedFilter;
  final ValueChanged<_CalendarFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _CalendarFilter.values) ...[
            _FilterChipButton(
              label: filter.label,
              selected: filter == selectedFilter,
              onTap: () => onChanged(filter),
            ),
            if (filter != _CalendarFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.red : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.red : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCalendarFilter extends StatelessWidget {
  const _EmptyCalendarFilter({required this.filter});

  final _CalendarFilter filter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '${filter.label} 상태의 그랑프리가 없습니다.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '2026 시즌 캘린더',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${races.length}개 그랑프리',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RaceCard extends StatelessWidget {
  const _RaceCard({required this.race, required this.onTap});

  final Race race;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = getRaceDisplayStatus(race);

    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _borderColor(status)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RoundBadge(round: race.round),
                            const Spacer(),
                            _StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          race.countryKo,
                          style: textTheme.labelMedium?.copyWith(
                            color: AppColors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          race.nameKo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          icon: Icons.route_outlined,
                          text: race.circuitKo,
                        ),
                        const SizedBox(height: 7),
                        _InfoLine(
                          icon: Icons.calendar_today_outlined,
                          text: _formatDateRange(race.startDate, race.endDate),
                        ),
                        if (race.hasSprint) ...[
                          const SizedBox(height: 12),
                          const _SprintBadge(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.round});

  final int round;

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
        '라운드 $round',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 7),
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

Color _statusColor(String status) {
  return switch (status) {
    RaceStatus.inProgress || RaceStatus.cancelled => AppColors.red,
    RaceStatus.scheduled => AppColors.white,
    _ => AppColors.textMuted,
  };
}

Color _borderColor(String status) {
  return status == RaceStatus.inProgress
      ? AppColors.red.withValues(alpha: 0.7)
      : AppColors.border;
}
