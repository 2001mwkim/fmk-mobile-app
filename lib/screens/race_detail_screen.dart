import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/circuit_info.dart';
import '../data/race_results.dart';
import '../data/races.dart';
import '../data/team_colors.dart';
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
    final raceSession = _raceSessionOf(race);
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
            if (top3.isNotEmpty) ...[
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.race, required this.status});

  final Race race;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      accent: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackMapPanel(race: race, status: status),
          Padding(
            padding: const EdgeInsets.all(16),
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
          ),
        ],
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
    return SizedBox(
      height: 158,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.black,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _SvgCircuitMap(assetPath: _circuitAssetPath(race.id)),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _MetaBadge(text: 'ROUND ${race.round}'),
            ),
            Positioned(right: 12, top: 12, child: _StatusBadge(status: status)),
          ],
        ),
      ),
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
          return CustomPaint(
            painter: _SvgPathPainter(_parseSvg(snapshot.data!)),
            child: const SizedBox.expand(),
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
    return Center(
      child: Text(
        '서킷 트랙맵 이미지 준비 중',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RaceStartCard extends StatelessWidget {
  const _RaceStartCard({required this.session});

  final RaceSession session;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '레이스 · 한국시간 기준',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '레이스 시작',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
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
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                session.time,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
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
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('세션 일정'),
          const SizedBox(height: 12),
          if (race.sessions.isEmpty)
            Text(
              race.cancelNote ?? '세션 일정이 없습니다.',
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
        _MetricData('총 거리', '${_formatNumber(info.distanceKm!)} km'),
      if (info.firstYear != null) _MetricData('첫 개최', '${info.firstYear}'),
    ];

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('서킷 정보'),
          const SizedBox(height: 4),
          Text(
            '${race.circuitKo} · ${race.cityKo}, ${race.countryKo}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (metrics.isNotEmpty) ...[
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
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Circuit layouts: F1DB (CC BY 4.0)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
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
          Row(
            children: [
              const Expanded(child: _SectionTitle('레이스 결과')),
              Text(
                'TOP 3',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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
    final teamColor = getTeamColor(result.teamKo);
    final teamColorOpacity = isLightTeamColor(result.teamKo) ? 0.7 : 1.0;
    final resultTime = result.gap ?? result.time ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              result.positionLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.red,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: teamColor.withValues(alpha: teamColorOpacity),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.driverKo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.teamKo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              Text(
                resultTime,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '+${_formatPoints(result.points)} PTS',
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

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.child,
    this.accent = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final bool accent;
  final EdgeInsetsGeometry padding;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: padding, child: child),
      ),
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
        color: AppColors.black.withValues(alpha: 0.72),
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

String _formatPoints(num points) {
  if (points is int || points == points.roundToDouble()) {
    return points.toInt().toString();
  }

  return points.toString();
}

Color _statusColor(String status) {
  return switch (status) {
    RaceStatus.inProgress || RaceStatus.cancelled => AppColors.red,
    RaceStatus.scheduled => AppColors.white,
    _ => AppColors.textMuted,
  };
}
