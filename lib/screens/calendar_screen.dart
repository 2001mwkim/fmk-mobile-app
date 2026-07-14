import 'package:flutter/material.dart';

import '../widgets/flag_icon.dart';
import '../data/races.dart';
import '../models/race.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_ui.dart';
import 'race_detail_screen.dart';

// 웹 calendar 전용 색 (globals/CalendarClient 에서 사용하는 값).
const Color _muted = AppColors.muted; // #7880a0
const Color _nameMuted = AppColors.nameMuted; // #aab0cc (비활성 카드 이름)
const Color _endedSurface = AppColors.tileSurface; // #0e1018 (비활성 카드 표면)
const Color _hairline = AppColors.hairline; // white/8
const Color _faintLine = AppColors.faintBorder; // white/6

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
    final nextRaceId = _nextRaceId();
    // 활성 → 비활성 경계(첫 비활성 인덱스). 전체 탭에서만 0보다 커진다.
    final firstInactiveIndex = visibleRaces.indexWhere(_isInactive);

    final children = <Widget>[
      const AppPageHeader(title: '시즌 캘린더', eyebrow: '2026 SEASON'),
      const SizedBox(height: 16),
      _FilterTabs(
        selectedFilter: _selectedFilter,
        onChanged: (filter) => setState(() => _selectedFilter = filter),
      ),
      const SizedBox(height: 14),
      _SubHeader(filter: _selectedFilter, count: visibleRaces.length),
      const SizedBox(height: 12),
    ];

    if (visibleRaces.isEmpty) {
      children.add(const _EmptyState());
    } else {
      for (var i = 0; i < visibleRaces.length; i++) {
        final race = visibleRaces[i];
        final inactive = _isInactive(race);

        if (firstInactiveIndex > 0 && i == firstInactiveIndex) {
          children.add(const _InactiveDivider());
        }

        void openDetail() {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RaceDetailScreen(race: race),
            ),
          );
        }

        if (inactive) {
          children.add(_CompactRaceCard(race: race, onTap: openDetail));
          children.add(const SizedBox(height: 10));
        } else {
          children.add(
            _ActiveRaceCard(
              race: race,
              isNext: race.id == nextRaceId,
              onTap: openDetail,
            ),
          );
          children.add(const SizedBox(height: 12));
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: children,
        ),
      ),
    );
  }

  // 종료(취소 포함) 그랑프리는 비활성 그룹.
  bool _isInactive(Race race) =>
      race.isCancelled || getRaceStatus(race) == RaceStatus.ended;

  // 진행중 GP가 없을 때만 가장 가까운 예정 그랑프리를 NEXT로 강조.
  String? _nextRaceId() {
    final hasOngoing = races.any(
      (race) =>
          !race.isCancelled && getRaceStatus(race) == RaceStatus.inProgress,
    );
    if (hasOngoing) return null;

    final upcoming =
        races
            .where(
              (race) =>
                  !race.isCancelled &&
                  getRaceStatus(race) == RaceStatus.scheduled,
            )
            .toList()
          ..sort(_byStartDateAsc);
    return upcoming.isEmpty ? null : upcoming.first.id;
  }

  List<Race> _filteredRaces(_CalendarFilter filter) {
    if (filter == _CalendarFilter.all) {
      final active = races.where((race) => !_isInactive(race)).toList()
        ..sort(_byStartDateAsc);
      final inactive = races.where(_isInactive).toList()..sort(_byStartDateAsc);
      return [...active, ...inactive];
    }

    if (filter == _CalendarFilter.ended) {
      return races.where(_isInactive).toList()..sort(_byStartDateAsc);
    }

    // 예정 / 진행중: 취소 건은 제외하고 가까운 일정 순으로.
    return races
        .where(
          (race) => !race.isCancelled && getRaceStatus(race) == filter.label,
        )
        .toList()
      ..sort(_byStartDateAsc);
  }
}

// startDate(YYYY-MM-DD) 사전식 비교 = 날짜 오름차순.
int _byStartDateAsc(Race a, Race b) => a.startDate.compareTo(b.startDate);

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selectedFilter, required this.onChanged});

  final _CalendarFilter selectedFilter;
  final ValueChanged<_CalendarFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<_CalendarFilter>(
      values: _CalendarFilter.values,
      selected: selectedFilter,
      labelFor: (filter) => filter.label,
      onChanged: onChanged,
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.filter, required this.count});

  final _CalendarFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = filter == _CalendarFilter.all
        ? '다가오는 그랑프리'
        : '${filter.label} 그랑프리';

    return AppSectionHeader(title: label, meta: '$count');
  }
}

class _InactiveDivider extends StatelessWidget {
  const _InactiveDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          const Text(
            '종료된 그랑프리',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textEnded,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _faintLine)),
        ],
      ),
    );
  }
}

class _ActiveRaceCard extends StatelessWidget {
  const _ActiveRaceCard({
    required this.race,
    required this.isNext,
    required this.onTap,
  });

  final Race race;
  final bool isNext;
  final VoidCallback onTap;

  // 다음 그랑프리(NEXT)뿐 아니라 현재 진행중 그랑프리도 동일하게 강조한다.
  bool get _emphasized =>
      isNext || getRaceStatus(race) == RaceStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    if (!_emphasized) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        onTap: onTap,
        child: _compactContent(context),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      borderColor: AppColors.red,
      child: _content(context),
    );
  }

  Widget _compactContent(BuildContext context) {
    final dateText =
        '${_shortDate(race.startDate)} – ${_shortDate(race.endDate)}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Flag(race.countryKo, size: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'R${race.round}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textEnded,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (race.hasSprint) ...[
                    const SizedBox(width: 6),
                    const AppChip(label: '스프린트', variant: AppChipVariant.blue),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      race.nameKo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${race.circuitKo} · ${race.cityKo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final status = getRaceStatus(race);
    final statusVariant = _emphasized
        ? AppChipVariant.red
        : AppChipVariant.neutral;
    final dateText =
        '${_shortDate(race.startDate)} – ${_shortDate(race.endDate)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppChip(label: 'R${race.round}', variant: AppChipVariant.mono),
                if (race.hasSprint) ...[
                  const SizedBox(width: 6),
                  const AppChip(label: '스프린트', variant: AppChipVariant.blue),
                ],
              ],
            ),
            AppChip(label: status, variant: statusVariant),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Flag(race.countryKo, size: 22),
            Expanded(
              child: Text(
                race.nameKo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        if (_emphasized) ...[
          const SizedBox(height: 10),
          _RaceInfoLine(
            dateText: dateText,
            venueText: '${race.circuitKo} · ${race.cityKo}',
            dateStyle: const TextStyle(
              fontSize: 15,
              fontFamily: 'Pretendard',
              color: AppColors.redSoft,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _hairline)),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '상세 일정 보기',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.redSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '→',
                  style: TextStyle(fontSize: 14, color: AppColors.redSoft),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          _RaceInfoLine(
            dateText: dateText,
            venueText: '${race.circuitKo} · ${race.cityKo}',
          ),
        ],
      ],
    );
  }
}

class _RaceInfoLine extends StatelessWidget {
  const _RaceInfoLine({
    required this.dateText,
    required this.venueText,
    this.dateStyle,
  });

  final String dateText;
  final String venueText;
  final TextStyle? dateStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          dateText,
          style:
              dateStyle ??
              const TextStyle(
                fontSize: 15,
                fontFamily: 'Pretendard',
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            venueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _CompactRaceCard extends StatelessWidget {
  const _CompactRaceCard({required this.race, required this.onTap});

  final Race race;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _endedSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _faintLine),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'R${race.round}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: AppColors.textEnded,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Flag(race.countryKo, size: 18),
                      Expanded(
                        child: Text(
                          race.nameKo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: _nameMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: race.isCancelled ? '취소' : '종료',
                  variant: AppChipVariant.ended,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.countryKo, {required this.size});

  final String countryKo;
  final double size;

  @override
  Widget build(BuildContext context) {
    // 이모지 대신 벡터 국기(FlagIcon) — 기기별 이모지 룩 편차 제거.
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FlagIcon(countryKo: countryKo, size: size),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppStateView(message: '표시할 그랑프리가 없습니다.\n다른 필터를 선택해보세요.');
  }
}

// 웹 formatDate: "M.D" (앞자리 0 제거, 연도 없음).
String _shortDate(String date) {
  final parts = date.split('-');
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  return '$month.$day';
}
