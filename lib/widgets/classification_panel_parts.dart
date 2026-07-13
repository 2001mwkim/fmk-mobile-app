import 'package:flutter/material.dart';

import '../models/live_session.dart' show livePodiumColors;
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// 라이브 순위 패널과 최종 결과 패널이 공유하는 시각 요소 모음.
///
/// 두 패널은 데이터 출처(라이브 스냅샷 vs 내장 결과 데이터)만 다르고
/// 카드 셸·컬럼 헤더·순위 행·'4위 이하' 확장 UI 는 동일한 디자인을 쓴다.
/// 스타일을 바꿀 때는 이 파일만 수정하면 두 패널에 함께 반영된다.

/// 패널 카드 셸: 어두운 카드 + 라운드 + 보더 + 내용 클리핑.
class ClassificationPanelShell extends StatelessWidget {
  const ClassificationPanelShell({
    super.key,
    required this.borderColor,
    required this.children,
  });

  static const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

  final Color borderColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141019),
        borderRadius: _radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// 패널 헤더 배경: 라이브(빨강) / 종료(흰색) 그라데이션.
class ClassificationHeaderContainer extends StatelessWidget {
  const ClassificationHeaderContainer({
    super.key,
    required this.emphasized,
    required this.child,
  });

  /// true 면 라이브(빨간 톤), false 면 종료(중립 톤) 그라데이션.
  final bool emphasized;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: emphasized
              ? const [Color(0x14EF4444), Color(0x00EF4444)]
              : const [Color(0x08FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: child,
    );
  }
}

/// POS / DRIVER / [timeLabel] 컬럼 헤더.
class ClassificationColumnHeader extends StatelessWidget {
  const ClassificationColumnHeader({super.key, required this.timeLabel});

  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 9,
      fontFamily: kDisplayFontFamily,
      color: AppColors.faint,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.8,
    );
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black20,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 26, child: Text('POS', style: style)),
          const SizedBox(width: 11),
          const Expanded(child: Text('DRIVER', style: style)),
          Text(timeLabel, style: style),
        ],
      ),
    );
  }
}

/// 순위 한 행: 순위 배지 · 팀컬러 바 · (코드) · 이름(부제) · 시간/갭.
class ClassificationRow extends StatelessWidget {
  const ClassificationRow({
    super.key,
    required this.position,
    this.positionLabel,
    required this.accentColor,
    this.code,
    required this.name,
    this.subtitle,
    required this.trailing,
  });

  final int position;

  /// 배지에 표시할 라벨. null 이면 순위 숫자. 'DNF'/'DNS' 등 문자 라벨 지원.
  final String? positionLabel;

  /// 팀/드라이버 컬러 바.
  final Color accentColor;

  /// 드라이버 약어(NOR 등). 라이브 패널에서만 사용.
  final String? code;

  final String name;

  /// 이름 아래 보조 텍스트(팀명 등). 결과 패널에서만 사용.
  final String? subtitle;

  /// 우측 시간/갭 텍스트. '—' 면 흐리게 표시.
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final isTopThree = position <= 3;
    final podium = livePodiumColors(position);
    final label = positionLabel ?? '$position';
    final isNumericLabel = int.tryParse(label) != null;

    return Container(
      decoration: BoxDecoration(
        color: isTopThree ? const Color(0x09FFFFFF) : null, // white/3.5
        border: const Border(top: BorderSide(color: AppColors.rowBorder)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTopThree ? 9 : 8,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: podium.background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isNumericLabel ? 12 : 8,
                fontFamily: kDisplayFontFamily,
                color: podium.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (code != null) ...[
            SizedBox(
              width: 38,
              child: Text(
                code!,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: kDisplayFontFamily,
                  color: isTopThree
                      ? const Color(0xFFE8EDF6)
                      : AppColors.slate300,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isTopThree ? AppColors.white : AppColors.nameMuted,
                    fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.faint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontFamily: kDisplayFontFamily,
              color: trailing == '—'
                  ? AppColors.faint
                  : (isTopThree ? AppColors.nameMuted : AppColors.muted),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// '4위 이하 순위 보기 / 순위 접기' 확장 영역. 자체적으로 펼침 상태를 관리한다.
class ClassificationExpander extends StatefulWidget {
  const ClassificationExpander({
    super.key,
    required this.accent,
    required this.startPosition,
    required this.endPosition,
    required this.count,
    required this.rows,
  });

  /// 펼치기/접기 라벨 색(라이브면 레드, 종료면 중립).
  final Color accent;
  final int startPosition;
  final int endPosition;
  final int count;
  final List<Widget> rows;

  @override
  State<ClassificationExpander> createState() => _ClassificationExpanderState();
}

class _ClassificationExpanderState extends State<ClassificationExpander> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.black20,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.rowBorder)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _expanded ? '순위 접기' : '4위 이하 순위 보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded
                            ? '${widget.startPosition}-${widget.endPosition}위'
                            : '+ ${widget.count}명 더',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'Pretendard',
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _expanded ? '↑' : '↓',
                        style: TextStyle(fontSize: 11, color: widget.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...widget.rows,
      ],
    );
  }
}
