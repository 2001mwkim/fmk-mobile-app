import 'package:flutter/material.dart';

import '../data/circuit_info.dart';
import '../widgets/flag_icon.dart';
import '../data/race_results.dart';
import '../data/races.dart';
import '../models/circuit_info.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/race_session.dart';
import '../services/race_results_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/circuit_map.dart';
import '../widgets/live_session_builder.dart';
import '../widgets/race_live_classification_panel.dart';
import '../widgets/race_result_classification_panel.dart';

// 웹 상세 페이지 전용 색 (page.tsx / globals 에서 사용하는 값).
const Color _muted = AppColors.muted; // #7880a0
const Color _heroSub = AppColors.heroSub; // #8088a8
const Color _nameMuted = AppColors.nameMuted; // #aab0cc
const Color _tileSurface = AppColors.tileSurface; // #0e1018
const Color _faintBorder = AppColors.faintBorder; // white/6

class RaceDetailScreen extends StatefulWidget {
  const RaceDetailScreen({
    super.key,
    required this.race,
    this.resultsRepository,
  });

  final Race race;

  /// 테스트/개발용 주입 지점. 기본값은 실서버(/api/race-results).
  final RaceResultsRepository? resultsRepository;

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  Race get race => widget.race;

  // 첫 프레임은 번들된 정적 결과(없으면 빈 목록 → "준비 중" 카드)로 그리고,
  // 서버 결과(세션별)가 오면 교체한다. 서버 실패/미존재 시 기존 상태 유지.
  late List<RaceResultEntry> _results;

  /// 서버가 내려준 세션별 결과(FP1~레이스, 주말 순서). null 이면 정적 경로.
  List<SessionResultData>? _sessions;
  String? _selectedSessionType;

  @override
  void initState() {
    super.initState();
    _results = getRaceResults(race.id) ?? const <RaceResultEntry>[];
    if (getRaceStatus(race) == RaceStatus.ended && !race.isCancelled) {
      _refreshResults();
    }
  }

  Future<void> _refreshResults() async {
    final repository =
        widget.resultsRepository ?? const HttpRaceResultsRepository();
    List<SessionResultData>? sessions;
    try {
      sessions = await repository.fetchSessionResults(raceId: race.id);
    } catch (_) {
      return; // 어떤 실패도 화면을 깨지 않는다 — 기존 카드 유지.
    }
    if (sessions == null || sessions.isEmpty || !mounted) return;
    setState(() {
      _sessions = sessions;
      // 기본 선택: 레이스(주말의 결론). 아직 레이스 전이면 가장 최근 세션.
      _selectedSessionType = sessions!.any((s) => s.sessionType == 'RACE')
          ? 'RACE'
          : sessions.last.sessionType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race);
    final circuitInfo = getCircuitInfo(race.id);
    // 종료(취소 제외) 그랑프리면 결과 노출 (결과 없으면 placeholder).
    final showResultCard =
        getRaceStatus(race) == RaceStatus.ended && !race.isCancelled;
    final results = showResultCard ? _results : const <RaceResultEntry>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppLayout.pagePadding(context),
          children: [
            const _DetailBackButton(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                race.isCancelled ? '그랑프리 상세 · 취소됨' : '그랑프리 상세 · R${race.round}',
                style: const TextStyle(
                  fontSize: 11,
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 라이브 순위 패널 (실데이터 없으면 렌더되지 않음)
            LiveSessionBuilder(
              builder: (_, snapshot, isStale) => RaceLiveClassificationPanel(
                snapshot: snapshot,
                raceId: race.id,
                isStale: isStale,
              ),
            ),
            _HeroCard(race: race, status: status),
            if (showResultCard) ...[
              const SizedBox(height: 12),
              // 서버 세션별 결과가 있으면 세션 선택 탭 + 패널.
              // 없으면 번들 정적 레이스 결과, 그마저 없으면 placeholder 유지.
              if (_sessions != null)
                _buildSessionResults()
              else if (results.isEmpty)
                const _RaceResultsPlaceholderCard()
              else
                RaceResultClassificationPanel(results: results),
            ],
            const SizedBox(height: 12),
            _SessionScheduleCard(race: race),
            if (circuitInfo != null) ...[
              const SizedBox(height: 12),
              _CircuitInfoCard(race: race, info: circuitInfo),
            ],
          ],
        ),
      ),
    );
  }

  /// 세션 선택 탭 + 선택된 세션의 결과 패널.
  Widget _buildSessionResults() {
    final sessions = _sessions!;
    final selected = sessions.firstWhere(
      (s) => s.sessionType == _selectedSessionType,
      orElse: () => sessions.last,
    );
    // 레이스/스프린트만 갭 기반 표기(연습·퀄리는 행별 랩타임).
    final gapBased =
        selected.sessionType == 'RACE' || selected.sessionType == 'SPRINT';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sessions.length > 1) ...[
          _SessionResultTabs(
            types: [for (final s in sessions) s.sessionType],
            selected: selected.sessionType,
            onChanged: (type) => setState(() => _selectedSessionType = type),
          ),
          const SizedBox(height: 10),
        ],
        RaceResultClassificationPanel(
          results: selected.data.entries,
          statusLabel: selected.data.isOfficial ? '공식 결과' : '잠정 결과',
          title: '${raceSessionTypeLabel(selected.sessionType)} 결과',
          gapBased: gapBased,
        ),
      ],
    );
  }
}

/// 세션별 결과 선택 탭(FP1 | 퀄리파잉 | 레이스 …). 순위 탭 토글과 같은
/// 알약 스타일 — 활성 칩은 레드 배경.
class _SessionResultTabs extends StatelessWidget {
  const _SessionResultTabs({
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<String> types;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in types) ...[
            _chip(type),
            if (type != types.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _chip(String type) {
    final isActive = type == selected;
    return Material(
      color: isActive ? AppColors.red : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.hairline,
            ),
          ),
          child: Text(
            raceSessionTypeLabel(type),
            style: TextStyle(
              fontSize: 12,
              color: isActive ? AppColors.white : AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            padding: const EdgeInsets.only(left: 10, right: 14),
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left, size: 22, color: AppColors.white),
                SizedBox(width: 2),
                Text(
                  '일정으로',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.race, required this.status});

  final Race race;
  final String status;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: _radius,
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrackMapPanel(race: race, status: status),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Flag(race.countryKo, size: 26),
                      Expanded(
                        child: Text(
                          race.nameKo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${race.circuitKo} · ${race.locationLabel}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _heroSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${race.startDate} – ${race.endDate}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      color: AppColors.redSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (race.hasSprint) ...[
                    const SizedBox(height: 12),
                    const AppChip(
                      label: '스프린트 주말',
                      variant: AppChipVariant.blue,
                    ),
                  ],
                  if (race.isCancelled && race.cancelNote != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      race.cancelNote!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackMapPanel extends StatelessWidget {
  const _TrackMapPanel({required this.race, required this.status});

  final Race race;
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusVariant = status == RaceStatus.inProgress
        ? AppChipVariant.red
        : AppChipVariant.neutral;

    return SizedBox(
      height: 158,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _faintBorder)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SvgCircuitMap(assetPath: _circuitAssetPath(race.id)),
            ),
            Positioned(
              left: 14,
              top: 12,
              child: _RoundPill(
                label: race.isCancelled ? '취소된 그랑프리' : 'ROUND ${race.round}',
              ),
            ),
            Positioned(
              right: 14,
              top: 12,
              child: AppChip(label: status, variant: statusVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundPill extends StatelessWidget {
  const _RoundPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x80000000), // black/50
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'Pretendard',
          color: AppColors.slate300,
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.only(right: 10),
      child: FlagIcon(countryKo: countryKo, size: size),
    );
  }
}

class _SessionScheduleCard extends StatelessWidget {
  const _SessionScheduleCard({required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('세션 일정'),
          const SizedBox(height: 14),
          if (race.sessions.isEmpty)
            Text(
              race.cancelNote ?? '세션 일정이 없습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            )
          else
            _SessionScheduleList(race: race),
        ],
      ),
    );
  }
}

// 세션 일정: 서킷 정보 박스와 같은 구조(tileSurface 박스 + 뮤트 라벨 +
// 화이트 값)로 앱 언어에 맞춘다. 하루(금/토/일)를 뮤트 날짜 라벨로 구분하고
// 그 아래 세션 행(명칭 좌 · 시간 우)을 나열한다. 세션 명칭·시간은 데이터
// 그대로(24h KST). 레드는 라이브 세션에만(앱 액센트 규칙), 종료는 흐리게.
class _SessionScheduleList extends StatelessWidget {
  const _SessionScheduleList({required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // 날짜(=하루)별 그룹화 — 데이터 순서(금→토→일) 유지.
    final groups = <_SessionGroup>[];
    for (final session in race.sessions) {
      if (groups.isNotEmpty && groups.last.date == session.date) {
        groups.last.sessions.add(session);
      } else {
        groups.add(_SessionGroup(session.date, [session]));
      }
    }

    final children = <Widget>[];
    for (var g = 0; g < groups.length; g++) {
      if (g > 0) children.add(const SizedBox(height: 12));
      children.add(_DayLabel(date: groups[g].date));
      children.add(const SizedBox(height: 2));
      for (final session in groups[g].sessions) {
        children.add(
          _SessionRow(
            status: getSessionStatus(race, session, now),
            session: session,
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        border: Border.all(color: _faintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.date});

  // date 포맷은 "8.21 금" — "8.21 (금)" 으로 표기한다.
  final String date;

  @override
  Widget build(BuildContext context) {
    final parts = date.split(' ');
    final dateText = parts.isNotEmpty ? parts.first : date;
    final dowText = parts.length > 1 ? parts[1] : '';
    final label = dowText.isEmpty ? dateText : '$dateText ($dowText)';

    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontFamily: 'Pretendard',
        color: _muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.status, required this.session});

  final SessionStatus status;
  final RaceSession session;

  @override
  Widget build(BuildContext context) {
    final isLive = status == SessionStatus.live;
    final isEnded = status == SessionStatus.ended;
    final color = isLive ? AppColors.redSoft : AppColors.white;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: isLive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            session.time,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Pretendard',
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (isEnded) {
      row = Opacity(opacity: 0.4, child: row);
    }
    return row;
  }
}

class _SessionGroup {
  _SessionGroup(this.date, this.sessions);

  final String date;
  final List<RaceSession> sessions;
}

class _CircuitInfoCard extends StatelessWidget {
  const _CircuitInfoCard({required this.race, required this.info});

  final Race race;
  final CircuitInfo info;

  @override
  Widget build(BuildContext context) {
    final metrics = <_MetricData>[
      if (info.lengthKm != null)
        _MetricData('서킷 길이', '${_formatNumber(info.lengthKm!)} km'),
      if (info.turns != null) _MetricData('코너 수', '${info.turns}'),
      if (info.laps != null) _MetricData('레이스 랩 수', '${info.laps}'),
      if (info.distanceKm != null)
        _MetricData('총 거리', '${info.distanceKm!.toStringAsFixed(1)} km'),
      if (info.firstYear != null) _MetricData('첫 개최', '${info.firstYear}'),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('서킷 정보'),
          const SizedBox(height: 6),
          Text(
            '${race.circuitKo} · ${race.locationLabel}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 12),
            _CompactMetrics(metrics: metrics),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: _faintBorder),
          const SizedBox(height: 10),
          const Text(
            'Circuit layouts: F1DB (CC BY 4.0)',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textEnded,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// 서킷 지표를 하나의 조밀한 3열 그리드로 묶는다(기존엔 지표마다 테두리
// 타일이라 세로로 길었다). 값(위)·라벨(아래)만 남겨 높이를 압축한다.
class _CompactMetrics extends StatelessWidget {
  const _CompactMetrics({required this.metrics});

  final List<_MetricData> metrics;

  static const int _cols = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += _cols) {
      final cells = <Widget>[];
      for (var c = 0; c < _cols; c++) {
        final idx = i + c;
        if (c > 0) cells.add(const SizedBox(width: 12));
        cells.add(
          Expanded(
            child: idx < metrics.length
                ? _CompactMetric(data: metrics[idx])
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 14));
      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        border: Border.all(color: _faintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: rows),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Pretendard',
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 결과 데이터가 아직 없는 종료 그랑프리용 placeholder 카드.
/// (결과가 있으면 [RaceResultClassificationPanel] 이 대신 렌더링된다.)
class _RaceResultsPlaceholderCard extends StatelessWidget {
  const _RaceResultsPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle('레이스 결과'),
          SizedBox(height: 14),
          _ResultsPlaceholder(),
        ],
      ),
    );
  }
}

class _ResultsPlaceholder extends StatelessWidget {
  const _ResultsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DottedBorderBox(
      child: Column(
        children: const [
          Text(
            '결과 데이터 준비 중',
            style: TextStyle(
              fontSize: 14,
              color: _nameMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '공식 결과가 반영되면 표시됩니다.',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
        ],
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 웹 border-dashed 근사: 실선 보더 + 어두운 표면.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _tileSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
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
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final String value;
}

String _circuitAssetPath(String raceId) => 'assets/circuits/$raceId.svg';

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
