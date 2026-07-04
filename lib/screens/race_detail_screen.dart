import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/circuit_info.dart';
import '../data/country_flags.dart';
import '../data/race_results.dart';
import '../data/races.dart';
import '../data/team_colors.dart';
import '../models/circuit_info.dart';
import '../models/race.dart';
import '../models/race_result.dart';
import '../models/race_session.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/live_session_builder.dart';
import '../widgets/race_live_classification_panel.dart';

// 웹 상세 페이지 전용 색 (page.tsx / globals 에서 사용하는 값).
const Color _muted = Color(0xFF7880A0); // #7880a0
const Color _heroSub = Color(0xFF8088A8); // #8088a8
const Color _nameMuted = Color(0xFFAAB0CC); // #aab0cc
const Color _tileSurface = Color(0xFF0E1018); // #0e1018
const Color _faintBorder = Color(0x0FFFFFFF); // white/6
const Color _hairline = Color(0x14FFFFFF); // white/8

class RaceDetailScreen extends StatelessWidget {
  const RaceDetailScreen({super.key, required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    final status = getRaceDisplayStatus(race);
    final circuitInfo = getCircuitInfo(race.id);
    final raceSession = _raceSessionOf(race);
    // 종료(취소 제외) 그랑프리면 결과 카드 노출 (포디움 없으면 placeholder).
    final showResultCard =
        getRaceStatus(race) == RaceStatus.ended && !race.isCancelled;
    final top3 = showResultCard
        ? getRaceTop3(race.id)
        : const <RaceResultEntry>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _DetailBackButton(),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '그랑프리 상세 · R${race.round}',
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
              _Top3ResultsCard(results: top3),
            ],
            if (raceSession != null) ...[
              const SizedBox(height: 12),
              _RaceStartCard(session: raceSession),
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

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: _radius,
        // to bottom right: #1c0f0e -> #1a1030 -> #141828
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C0F0E), Color(0xFF1A1030), Color(0xFF141828)],
        ),
      ),
      foregroundDecoration: const BoxDecoration(
        borderRadius: _radius,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0x4DEF4444)), // red-500/30
        ),
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
                    '${race.circuitKo} · ${race.cityKo}, ${race.countryKo}',
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
              child: _SvgCircuitMap(assetPath: _circuitAssetPath(race.id)),
            ),
            Positioned(left: 14, top: 12, child: _RoundPill(round: race.round)),
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
  const _RoundPill({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x80000000), // black/50
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'ROUND $round',
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
    final flag = getCountryFlag(countryKo);
    if (flag.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(flag, style: TextStyle(fontSize: size, height: 1)),
    );
  }
}

class _SvgCircuitMap extends StatelessWidget {
  const _SvgCircuitMap({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: CustomPaint(
              painter: _SvgPathPainter(_parseSvg(snapshot.data!)),
              child: const SizedBox.expand(),
            ),
          );
        }

        return const _TrackMapPlaceholder();
      },
    );
  }
}

class _TrackMapPlaceholder extends StatelessWidget {
  const _TrackMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    // 웹: repeating-linear-gradient(45deg, #0e1018 0 11px, #12141e 11px 22px)
    return SizedBox.expand(
      child: CustomPaint(
        painter: const _DiagonalBandsPainter(),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRACK MAP',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF6B7090),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '서킷 트랙맵 이미지 준비 중',
                style: TextStyle(fontSize: 11, color: AppColors.textEnded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagonalBandsPainter extends CustomPainter {
  const _DiagonalBandsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0E1018),
    );

    final paint = Paint()
      ..color = const Color(0xFF12141E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11; // 11px 밴드

    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(45 * math.pi / 180);
    final extent = size.width + size.height;
    for (double x = -extent; x <= extent; x += 22) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DiagonalBandsPainter oldDelegate) => false;
}

class _RaceStartCard extends StatelessWidget {
  const _RaceStartCard({required this.session});

  final RaceSession session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '레이스 · 한국시간 기준',
                  style: TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '레이스 시작',
                  style: TextStyle(
                    fontSize: 17,
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                session.date,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                session.time,
                style: const TextStyle(
                  fontSize: 27,
                  fontFamily: 'Pretendard',
                  height: 1,
                  color: AppColors.redSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('세션 일정'),
          const SizedBox(height: 16),
          if (race.sessions.isEmpty)
            Text(
              race.cancelNote ?? '세션 일정이 없습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            )
          else
            _SessionTimeline(race: race),
        ],
      ),
    );
  }
}

// 웹 RaceSessionTimeline: 날짜별 그룹 + 좌측 수직선 + 상태별 도트/박스.
class _SessionTimeline extends StatelessWidget {
  const _SessionTimeline({required this.race});

  final Race race;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // 날짜별 그룹화(데이터 순서 유지).
    final groups = <_SessionGroup>[];
    for (final session in race.sessions) {
      if (groups.isNotEmpty && groups.last.date == session.date) {
        groups.last.sessions.add(session);
      } else {
        groups.add(_SessionGroup(session.date, [session]));
      }
    }

    final rows = <Widget>[];
    for (final group in groups) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 24 + 12, bottom: 10),
          child: Text(
            group.date,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Pretendard',
              color: _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
      for (final session in group.sessions) {
        rows.add(
          _SessionTimelineRow(
            status: getSessionStatus(race, session, now),
            session: session,
          ),
        );
      }
    }

    return Stack(
      children: [
        // 수직 타임라인 라인(좌측 24px 칼럼 중앙).
        Positioned(
          left: 11,
          top: 4,
          bottom: 12,
          child: Container(width: 2, color: _hairline),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      ],
    );
  }
}

class _SessionTimelineRow extends StatelessWidget {
  const _SessionTimelineRow({required this.status, required this.session});

  final SessionStatus status;
  final RaceSession session;

  @override
  Widget build(BuildContext context) {
    final isLive = status == SessionStatus.live;
    final isEnded = status == SessionStatus.ended;
    final isRace = session.id == 'race';
    final emphasize = isLive || isRace;

    final labelStyle = TextStyle(
      fontSize: emphasize ? 15 : 14,
      color: emphasize ? AppColors.redSoft : _nameMuted,
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w600,
    );
    final timeStyle = TextStyle(
      fontSize: emphasize ? 17 : 15,
      fontFamily: 'Pretendard',
      color: emphasize ? AppColors.redSoft : _nameMuted,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
    );

    Widget box = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: isLive
          ? BoxDecoration(
              color: const Color(0x14EF4444), // red-500/8
              border: Border.all(color: const Color(0x4DEF4444)), // /30
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    session.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                if (isEnded) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '종료',
                    style: TextStyle(
                      fontSize: 10,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(session.time, style: timeStyle),
        ],
      ),
    );

    if (isEnded) {
      box = Opacity(opacity: 0.45, child: box);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Center(
              child: _TimelineDot(status: status, isRace: isRace),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: box),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.status, required this.isRace});

  final SessionStatus status;
  final bool isRace;

  @override
  Widget build(BuildContext context) {
    final isLive = status == SessionStatus.live;
    final isEnded = status == SessionStatus.ended;

    if (isLive || isRace) {
      return Container(
        width: 13,
        height: 13,
        decoration: const BoxDecoration(
          color: AppColors.red,
          shape: BoxShape.circle,
        ),
      );
    }
    if (isEnded) {
      return Container(
        width: 11,
        height: 11,
        decoration: const BoxDecoration(
          color: AppColors.textEnded,
          shape: BoxShape.circle,
        ),
      );
    }
    // upcoming: 빈 도트.
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0x33FFFFFF),
          width: 2,
        ), // white/20
      ),
    );
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
            '${race.circuitKo} · ${race.cityKo}, ${race.countryKo}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            _MetricGrid(metrics: metrics),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: _faintBorder),
          const SizedBox(height: 12),
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

// 웹 grid-cols-2 gap-2.5 재현 (2열 그리드).
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += 2) {
      final left = metrics[i];
      final right = i + 1 < metrics.length ? metrics[i + 1] : null;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricTile(label: left.label, value: left.value),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : _MetricTile(label: right.label, value: right.value),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _Top3ResultsCard extends StatelessWidget {
  const _Top3ResultsCard({required this.results});

  final List<RaceResultEntry> results;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SectionTitle('레이스 결과'),
              Text(
                'TOP 3',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Pretendard',
                  color: AppColors.redSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (results.isEmpty)
            const _ResultsPlaceholder()
          else
            for (var i = 0; i < results.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ResultRow(result: results[i]),
            ],
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final RaceResultEntry result;

  @override
  Widget build(BuildContext context) {
    final teamColor = getTeamColor(
      result.teamKo,
    ).withValues(alpha: isLightTeamColor(result.teamKo) ? 0.7 : 1.0);
    final resultTime = result.gap ?? result.time ?? '—';
    final badge = _podiumBadge(result.position);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        border: Border.all(color: _faintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badge.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${result.position}',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: badge.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.driverKo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: teamColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        result.teamKo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                resultTime,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: _nameMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '+${_formatPoints(result.points)} PTS',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Pretendard',
                  color: AppColors.textEnded,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 포디움 배지 색. 웹은 P1에 노란색을 쓰지만 앱 규칙상 노란색 금지 → P1은 레드 톤으로 대체.
({Color background, Color foreground}) _podiumBadge(int position) {
  switch (position) {
    case 1:
      return (
        background: const Color(0x26EF4444),
        foreground: AppColors.redSoft,
      );
    case 2:
      return (
        background: const Color(0x2694A3B8), // slate-400/15
        foreground: AppColors.slate300,
      );
    case 3:
      return (
        background: const Color(0x26F97316), // orange-500/15
        foreground: const Color(0xFFFB923C), // orange-400
      );
    default:
      return (background: const Color(0x0DFFFFFF), foreground: _muted);
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _tileSurface,
        border: Border.all(color: _faintBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontFamily: 'Pretendard',
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

class _SvgPathPainter extends CustomPainter {
  _SvgPathPainter(this.svg);

  final _ParsedSvg svg;

  @override
  void paint(Canvas canvas, Size size) {
    if (svg.paths.isEmpty || svg.viewBox.isEmpty) return;

    final scale = math.min(
      size.width / svg.viewBox.width,
      size.height / svg.viewBox.height,
    );
    final dx = (size.width - svg.viewBox.width * scale) / 2;
    final dy = (size.height - svg.viewBox.height * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    for (final item in svg.paths) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = item.strokeWidth
        ..color = item.color;
      canvas.drawPath(item.path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgPathPainter oldDelegate) => oldDelegate.svg != svg;
}

class _ParsedSvg {
  const _ParsedSvg({required this.viewBox, required this.paths});

  final Rect viewBox;
  final List<_SvgPathItem> paths;
}

class _SvgPathItem {
  const _SvgPathItem({
    required this.path,
    required this.strokeWidth,
    required this.color,
  });

  final Path path;
  final double strokeWidth;
  final Color color;
}

_ParsedSvg _parseSvg(String source) {
  final size = _readSvgSize(source);
  final pathRegExp = RegExp(r'<path\b[^>]*>', caseSensitive: false);
  final paths = <_SvgPathItem>[];

  for (final match in pathRegExp.allMatches(source)) {
    final tag = match.group(0)!;
    final data = _readAttribute(tag, 'd');
    if (data == null || data.isEmpty) continue;

    paths.add(
      _SvgPathItem(
        path: _SvgPathParser(data).parse(),
        strokeWidth: _readStrokeWidth(tag),
        color: _readStrokeColor(tag),
      ),
    );
  }

  return _ParsedSvg(viewBox: Offset.zero & size, paths: paths);
}

Size _readSvgSize(String source) {
  final svgTag = RegExp(
    r'<svg\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(source)?.group(0);
  if (svgTag == null) return const Size(500, 500);

  final width = double.tryParse(_readAttribute(svgTag, 'width') ?? '');
  final height = double.tryParse(_readAttribute(svgTag, 'height') ?? '');
  if (width != null && height != null) return Size(width, height);

  final viewBox = _readAttribute(svgTag, 'viewBox');
  final values = viewBox
      ?.split(RegExp(r'[\s,]+'))
      .map(double.tryParse)
      .whereType<double>()
      .toList();
  if (values != null && values.length == 4) {
    return Size(values[2], values[3]);
  }

  return const Size(500, 500);
}

String? _readAttribute(String tag, String name) {
  return RegExp(
    '$name="([^"]*)"',
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);
}

double _readStrokeWidth(String tag) {
  final width = RegExp(
    r'stroke-width:\s*([0-9.]+)',
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);
  return double.tryParse(width ?? '') ?? 4;
}

Color _readStrokeColor(String tag) {
  final stroke = RegExp(
    r'stroke:\s*(#[0-9a-fA-F]{3,6})',
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);
  if (stroke == '#000') return AppColors.black;
  return AppColors.white;
}

class _SvgPathParser {
  _SvgPathParser(String data) : _tokens = _tokenize(data);

  final List<String> _tokens;
  int _index = 0;
  String _command = '';
  Offset _current = Offset.zero;
  Offset _subPathStart = Offset.zero;

  Path parse() {
    final path = Path();
    while (_index < _tokens.length) {
      if (_isCommand(_tokens[_index])) {
        _command = _tokens[_index++];
      }
      _applyCommand(path);
    }
    return path;
  }

  void _applyCommand(Path path) {
    switch (_command) {
      case 'M':
      case 'm':
        _move(path, relative: _command == 'm');
        return;
      case 'L':
      case 'l':
        _line(path, relative: _command == 'l');
        return;
      case 'H':
      case 'h':
        _horizontal(path, relative: _command == 'h');
        return;
      case 'V':
      case 'v':
        _vertical(path, relative: _command == 'v');
        return;
      case 'C':
      case 'c':
        _cubic(path, relative: _command == 'c');
        return;
      case 'Q':
      case 'q':
        _quadratic(path, relative: _command == 'q');
        return;
      case 'A':
      case 'a':
        _arcAsLine(path, relative: _command == 'a');
        return;
      case 'Z':
      case 'z':
        path.close();
        _current = _subPathStart;
        return;
      default:
        _index++;
    }
  }

  void _move(Path path, {required bool relative}) {
    final point = _readPoint(relative: relative);
    path.moveTo(point.dx, point.dy);
    _current = point;
    _subPathStart = point;
    _command = relative ? 'l' : 'L';
  }

  void _line(Path path, {required bool relative}) {
    while (_hasNumber()) {
      final point = _readPoint(relative: relative);
      path.lineTo(point.dx, point.dy);
      _current = point;
    }
  }

  void _horizontal(Path path, {required bool relative}) {
    while (_hasNumber()) {
      final x = _readNumber() + (relative ? _current.dx : 0);
      _current = Offset(x, _current.dy);
      path.lineTo(_current.dx, _current.dy);
    }
  }

  void _vertical(Path path, {required bool relative}) {
    while (_hasNumber()) {
      final y = _readNumber() + (relative ? _current.dy : 0);
      _current = Offset(_current.dx, y);
      path.lineTo(_current.dx, _current.dy);
    }
  }

  void _cubic(Path path, {required bool relative}) {
    while (_hasNumber()) {
      final c1 = _readPoint(relative: relative);
      final c2 = _readPoint(relative: relative);
      final end = _readPoint(relative: relative);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      _current = end;
    }
  }

  void _quadratic(Path path, {required bool relative}) {
    while (_hasNumber()) {
      final c = _readPoint(relative: relative);
      final end = _readPoint(relative: relative);
      path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
      _current = end;
    }
  }

  void _arcAsLine(Path path, {required bool relative}) {
    while (_hasNumber()) {
      _readNumber();
      _readNumber();
      _readNumber();
      _readNumber();
      _readNumber();
      final end = _readPoint(relative: relative);
      path.lineTo(end.dx, end.dy);
      _current = end;
    }
  }

  Offset _readPoint({required bool relative}) {
    final x = _readNumber();
    final y = _readNumber();
    final point = Offset(x, y);
    return relative ? _current + point : point;
  }

  double _readNumber() => double.parse(_tokens[_index++]);

  bool _hasNumber() => _index < _tokens.length && !_isCommand(_tokens[_index]);

  static bool _isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
}

List<String> _tokenize(String data) {
  return RegExp(
    r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((match) => match.group(0)!).toList();
}

RaceSession? _raceSessionOf(Race race) {
  for (final session in race.sessions) {
    if (session.id == 'race') return session;
  }
  return null;
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

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }

  return points.toString();
}
