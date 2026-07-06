import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// assets/circuits/*.svg 트랙맵을 그리는 위젯.
///
/// F1DB 서킷 SVG 를 외부 패키지 없이 직접 파싱해 CustomPaint 로 렌더링한다.
/// 에셋이 없거나 로드 전이면 대각선 밴드 placeholder 를 보여준다.
class SvgCircuitMap extends StatelessWidget {
  const SvgCircuitMap({super.key, required this.assetPath});

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
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.tileSurface);

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
