import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/country_flags.dart';
import '../data/races.dart';
import '../models/live_session.dart';
import '../theme/app_colors.dart';

/// 웹 components/live/HomeLiveTopThreeCard.tsx 의 Flutter 이식.
///
/// snapshot 이 없거나 Top 3 가 3명 미만이면 아무것도 렌더하지 않는다(자리만 차지하지 않음).
/// 실데이터 연결 전에는 [snapshot] 이 null 로 들어와 화면에 노출되지 않는다.
class HomeLiveTopThreeCard extends StatelessWidget {
  const HomeLiveTopThreeCard({
    super.key,
    required this.snapshot,
    this.onTap,
    this.isStale = false,
    this.now,
  });

  final LiveSessionSnapshot? snapshot;
  final VoidCallback? onTap;

  /// 데이터 연결이 잠깐 흔들려 마지막 순위를 유지 중인 상태(3분 초과).
  final bool isStale;
  final DateTime? now;

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null || s.topThree.length < 3) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(context, s),
    );
  }

  Widget _card(BuildContext context, LiveSessionSnapshot s) {
    final ended = s.isEnded && !isLiveSnapshotSessionActive(s, now);

    final surface = Container(
      decoration: BoxDecoration(
        borderRadius: _radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ended
              ? const [Color(0xFF15161D), Color(0xFF141525), Color(0xFF141828)]
              : const [Color(0xFF1C0F12), Color(0xFF161126), Color(0xFF141828)],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(
          color: ended ? AppColors.border : const Color(0x66EF4444), // red/40
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          children: [
            if (!ended)
              const Positioned.fill(
                child: CustomPaint(painter: _LiveStripesPainter()),
              ),
            if (!ended) Positioned(right: -32, top: -44, child: _glow(160)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                  child: _topContent(context, s, ended),
                ),
                _footer(ended),
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      borderRadius: _radius,
      child: InkWell(borderRadius: _radius, onTap: onTap, child: surface),
    );
  }

  Widget _topContent(BuildContext context, LiveSessionSnapshot s, bool ended) {
    final raceLike = s.isRaceOrSprint;
    // raceId/raceName → races.dart 의 Race. 국기/한글 GP 이름을 여기서 함께 구한다.
    final race = resolveLiveRace(s.raceId, s.raceName);
    final flag =
        (race != null ? getCountryFlag(race.countryKo) : null) ??
        liveCountryFlag(s.raceId) ??
        s.countryFlag;
    final raceNameKo = race?.nameKo ?? s.raceName ?? 'Live Session';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _StatusBadge(ended: ended, label: liveEndedHomeLabel),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      s.sessionTitleKo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _LiveClock(label: s.updatedAtLabel, ended: ended),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (flag != null) ...[
              Text(flag, style: const TextStyle(fontSize: 18, height: 1)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                raceNameKo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (isStale) ...[const SizedBox(width: 8), const _StaleBadge()],
          ],
        ),
        const SizedBox(height: 10),
        _summaryRow(s, ended),
        const SizedBox(height: 8),
        for (var i = 0; i < 3; i++)
          _TopThreeRow(
            driver: s.topThree[i],
            raceLike: raceLike,
            isFirst: i == 0,
          ),
      ],
    );
  }

  Widget _summaryRow(LiveSessionSnapshot s, bool ended) {
    final label = ended ? s.topThreeLabel : s.summary;
    if (s.summary.startsWith('Lap')) {
      final lapText = s.summary.split(' · ').first.toUpperCase();
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x12FFFFFF), // white/7
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              lapText,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Pretendard',
                color: AppColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              s.topThreeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7880A0),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF7880A0),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _footer(bool ended) {
    final color = ended ? const Color(0xFFAAB0CC) : AppColors.redSoft;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0x33000000), // black/20
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))), // white/8
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '전체 순위 보기',
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('→', style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }

  Widget _glow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x33EF4444), Color(0x00EF4444)],
          stops: [0.0, 0.7],
        ),
      ),
    );
  }
}

/// 연결이 잠깐 흔들려 마지막 순위를 유지 중임을 알리는 muted 배지(경고 톤 아님).
class _StaleBadge extends StatelessWidget {
  const _StaleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF), // white/8
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        '업데이트 지연',
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'Pretendard',
          color: Color(0xFF8088A8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.ended, required this.label});

  final bool ended;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ended
            ? const Color(0x1AFFFFFF)
            : AppColors.red, // white/10 : red
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ended ? const Color(0xFF7880A0) : AppColors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ended ? label : 'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: ended ? const Color(0xFFAAB0CC) : AppColors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveClock extends StatelessWidget {
  const _LiveClock({required this.label, required this.ended});

  final String? label;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: ended ? const Color(0xFF7880A0) : AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label!,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Pretendard',
            color: Color(0xFF8088A8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TopThreeRow extends StatelessWidget {
  const _TopThreeRow({
    required this.driver,
    required this.raceLike,
    required this.isFirst,
  });

  final LiveDriverPosition driver;
  final bool raceLike;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final podium = livePodiumColors(driver.position);
    final gap = driver.gap(raceLike: raceLike);

    return Container(
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(
                top: BorderSide(color: Color(0x0FFFFFFF)),
              ), // white/6
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _RankBadge(position: driver.position, podium: podium, size: 20),
          const SizedBox(width: 11),
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: liveDriverAccent(driver.code),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 38,
            child: Text(
              driver.code,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: Color(0xFFE8EDF6),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              driver.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Text(
            gap,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Pretendard',
              color: gap == '—'
                  ? const Color(0xFF5B6178)
                  : const Color(0xFFAAB0CC),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.position,
    required this.podium,
    required this.size,
  });

  final int position;
  final ({Color background, Color foreground}) podium;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: podium.background,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$position',
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'Pretendard',
          color: podium.foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 웹 repeating-linear-gradient(108deg, transparent 0 24px, rgba(239,68,68,0.05) 24px 25px).
class _LiveStripesPainter extends CustomPainter {
  const _LiveStripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x0DEF4444) // rgba(239,68,68,~0.05)
      ..strokeWidth = 1;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(108 * math.pi / 180);
    final extent = size.width + size.height;
    for (double x = -extent; x <= extent; x += 25) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiveStripesPainter oldDelegate) => false;
}
