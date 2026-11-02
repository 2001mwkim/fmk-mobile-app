import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../data/team_colors.dart';
import '../models/race_result.dart';
import '../models/standing.dart';
import '../services/error_reporting.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// 결과·순위 공유 카드(인스타 피드 4:5 비율 이미지).
///
/// 한국어 이미지 카드가 인스타·카카오로 퍼지면 자연 유입이 생긴다(2026-11 개선
/// 목록). 카드는 앱 테마와 무관하게 항상 검정 바탕 — 어떤 테마에서 만들어도
/// 같은 브랜드 이미지로 보이게 한다. 공식 F1 로고·팀 로고는 넣지 않는다
/// (CLAUDE.md 라이선스 절).
const Size kShareCardSize = Size(360, 450);

/// 저장 이미지 배율 — 360×450 → 1080×1350(인스타 권장 해상도).
const double kShareCardPixelRatio = 3;

/// 카드의 한 줄(순위·이름·보조·값·팀 컬러).
class ShareRow {
  const ShareRow({
    required this.position,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
  });

  final String position;
  final String title;
  final String subtitle;
  final String value;
  final Color accent;
}

/// 세션 결과 → 카드 행(상위 [limit]명). 값 표기는 결과 패널과 같은 규칙:
/// 레이스/스프린트는 1위 총시간 + 나머지 갭, 연습/퀄리는 행별 랩타임.
List<ShareRow> shareRowsFromResults(
  List<RaceResultEntry> entries, {
  required bool gapBased,
  int limit = 10,
}) {
  return [
    for (final entry in entries.take(limit))
      ShareRow(
        position: entry.positionLabel,
        title: entry.driverKo,
        subtitle: entry.teamKo,
        value: gapBased
            ? (entry.position == 1 ? entry.time : entry.gap) ?? '—'
            : entry.time ?? entry.gap ?? '—',
        accent: getTeamColor(entry.teamKo),
      ),
  ];
}

List<ShareRow> shareRowsFromDriverStandings(
  List<DriverStanding> rows, {
  int limit = 10,
}) {
  return [
    for (final row in rows.take(limit))
      ShareRow(
        position: '${row.position}',
        title: row.driverKo,
        subtitle: row.teamKo,
        value: '${_points(row.points)} PTS',
        accent: getTeamColor(row.teamKo),
      ),
  ];
}

List<ShareRow> shareRowsFromConstructorStandings(
  List<ConstructorStanding> rows, {
  int limit = 10,
}) {
  return [
    for (final row in rows.take(limit))
      ShareRow(
        position: '${row.position}',
        title: row.teamKo,
        subtitle: row.teamEn,
        value: '${_points(row.points)} PTS',
        accent: getTeamColor(row.teamKo),
      ),
  ];
}

String _points(num points) =>
    points == points.roundToDouble() ? '${points.toInt()}' : '$points';

/// 공유 이미지 본체. 크기 고정([kShareCardSize]).
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.rows,
    this.note,
  });

  /// 카드 맨 위 작은 글자(예: 'R20 · 2026').
  final String eyebrow;

  /// 큰 제목(예: '멕시코 그랑프리 레이스 결과').
  final String title;
  final List<ShareRow> rows;

  /// 하단 보조 문구(예: '잠정 결과').
  final String? note;

  static const Color _ink = AppColors.pureWhite;
  static Color get _muted => AppColors.pureWhite.withValues(alpha: 0.55);
  static Color get _rule => AppColors.pureWhite.withValues(alpha: 0.12);

  @override
  Widget build(BuildContext context) {
    // 공유 이미지는 시스템 글자 크기 설정과 무관하게 같은 모양이어야 한다.
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: kShareCardSize,
        child: ColoredBox(
          color: AppColors.pureBlack,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: DefaultTextStyle(
              style: AppType.body.copyWith(
                color: _ink,
                fontFamily: 'Pretendard',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(eyebrow, style: AppType.caption.copyWith(color: _muted)),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.title.copyWith(color: _ink, fontSize: 20),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Column(
                      children: [
                        for (final row in rows)
                          Expanded(child: _Row(row: row, rule: _rule)),
                        for (var i = rows.length; i < 10; i++)
                          const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '비아 포뮬러',
                        style: AppType.subhead.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'formulamagazine.kr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: _muted),
                        ),
                      ),
                      if (note != null)
                        Text(
                          note!,
                          style: AppType.caption.copyWith(color: _muted),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.rule});

  final ShareRow row;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: rule)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              row.position,
              style: AppType.subhead.copyWith(
                color: ShareCard._ink,
                fontWeight: FontWeight.w700,
                fontFeatures: AppType.tabular,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: row.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: row.title,
                    style: AppType.subhead.copyWith(
                      color: ShareCard._ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '  ${row.subtitle}',
                    style: AppType.caption.copyWith(color: ShareCard._muted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.value,
            style: AppType.caption.copyWith(
              color: ShareCard._ink,
              fontFeatures: AppType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공유 미리보기 시트를 띄우고, '공유하기' 를 누르면 카드를 PNG 로 찍어
/// 시스템 공유 시트로 넘긴다.
Future<void> showShareCardSheet(
  BuildContext context, {
  required ShareCard card,
  required String fileName,
  String? text,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (_) => _ShareSheet(card: card, fileName: fileName, text: text),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.card, required this.fileName, this.text});

  final ShareCard card;
  final String fileName;
  final String? text;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: kShareCardPixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('png encode failed');
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: '${widget.fileName}.png',
            ),
          ],
          fileNameOverrides: ['${widget.fileName}.png'],
          text: widget.text,
          // iPad 는 공유 팝오버 기준 위치가 없으면 예외를 던진다.
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error, stackTrace) {
      reportSilentFailure('share_card', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('이미지를 공유하지 못했어요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('이미지로 공유', style: AppType.title.copyWith(color: AppColors.white)),
            const SizedBox(height: 16),
            // 미리보기는 화면 높이에 맞춰 줄이되, 캡처는 원래 크기로 한다
            // (FittedBox 는 그리기만 축소하고 RepaintBoundary 는 원본 크기다).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: FittedBox(
                child: ClipRRect(
                  borderRadius: AppRadius.cardBorder,
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: widget.card,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('공유하기'),
            ),
          ],
        ),
      ),
    );
  }
}
