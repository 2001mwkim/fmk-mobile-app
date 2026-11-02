import 'package:flutter/material.dart';

import '../models/licensed_image.dart';
import '../models/standing_insight.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'glass.dart';
import 'licensed_image_view.dart';

// 드라이버·컨스트럭터 상세 공용 부품(2026-10 재설계).
//
// 이전 구성(알약 뒤로가기 + 대문자 눈썹 + 사진 상자 옆 정보 + 색 아이콘 2x2
// 성적 타일 + 평평한 순위 흐름 선 + 최근 5경기)을 애플 스포츠 선수 페이지
// 방식으로 바꿨다: 화면 꼭대기를 사진(없으면 팀 색)으로 꽉 채운 헤더 →
// 성적 한 줄 → 시즌 포인트 상세 → 맞대결 → 프로필 → 시즌 전체 결과.

/// 정수 축에서 시작과 끝을 포함해 최대 4개의 겹치지 않는 눈금을 고른다.
/// 눈금 좌표도 반환한 실제 정숫값으로 계산해야 라벨과 데이터 선이 일치한다.
List<int> standingTrendAxisTicks(int start, int end) {
  if (end <= start) return [start];
  final valueCount = end - start + 1;
  final tickCount = valueCount < 4 ? valueCount : 4;
  return [
    for (var i = 0; i < tickCount; i++)
      start + ((end - start) * i / (tickCount - 1)).round(),
  ];
}

/// 상세 화면 뼈대: 꽉 찬 헤더가 상태 표시줄 밑까지 올라가고, 뒤로가기는
/// 스크롤과 무관하게 왼쪽 위에 떠 있는 유리 원으로 둔다.
class DetailPageScaffold extends StatelessWidget {
  const DetailPageScaffold({
    super.key,
    required this.hero,
    required this.children,
  });

  final Widget hero;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final gutter = 16 + AppLayout.contentGutter(context);
    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              bottom: 32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              hero,
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
          Positioned(
            top: top + 8,
            left: 12,
            child: const _GlassBackButton(),
          ),
        ],
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '뒤로',
      child: AppPressable(
        pressedScale: 0.92,
        onTap: () => Navigator.of(context).maybePop(),
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          tint: AppColors.pureBlack.withValues(alpha: 0.35),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: AppColors.pureWhite,
            ),
          ),
        ),
      ),
    );
  }
}

/// 상단 헤더. 사진이 있으면 꽉 채우고, 없으면 팀 색 그라데이션 위에 큰
/// 워터마크([fallbackMark], TLA 등)를 둔다. 아래쪽은 검정으로 내려가는 스크림이라
/// 사진 위 흰 글씨가 늘 읽히고, 다크 테마에선 본문 배경과 이음새 없이 이어진다.
class DetailHero extends StatelessWidget {
  const DetailHero({
    super.key,
    required this.accent,
    required this.image,
    required this.imageLabel,
    required this.fallbackMark,
    required this.child,
    this.height = 360,
  });

  final Color accent;
  final LicensedImage? image;
  final String imageLabel;
  final String fallbackMark;

  /// 헤더 아래쪽에 얹을 정보(이름·순위 등). 흰 글씨 기준으로 만들 것.
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final photo = image;
    return SizedBox(
      height: height + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 팀 색 바탕(사진이 없거나 로딩 중일 때 보인다).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  accent.withValues(alpha: 0.9),
                  Color.lerp(accent, AppColors.pureBlack, 0.7)!,
                ],
              ),
            ),
          ),
          if (photo == null)
            Positioned(
              right: -12,
              top: top + 24,
              child: Text(
                fallbackMark,
                style: TextStyle(
                  fontSize: 150,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -6,
                  color: AppColors.pureWhite.withValues(alpha: 0.10),
                ),
              ),
            )
          else
            Image.network(
              photo.imageUrl,
              fit: BoxFit.cover,
              alignment: licensedImageAlignment(photo.objectPosition),
              semanticLabel: imageLabel,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          // 사진에 팀 색을 살짝 얹어 화면마다 색 정체성이 남게 한다.
          if (photo != null)
            ColoredBox(color: accent.withValues(alpha: 0.12)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.25, 0.55, 1],
                colors: [
                  AppColors.pureBlack.withValues(alpha: 0.35),
                  AppColors.pureBlack.withValues(alpha: 0),
                  AppColors.pureBlack.withValues(alpha: 0.25),
                  AppColors.pureBlack,
                ],
              ),
            ),
          ),
          if (photo != null)
            Positioned(
              top: top + 12,
              right: 12,
              child: LicensedImageCreditButton(image: photo),
            ),
          Positioned(
            left: 20 + AppLayout.contentGutter(context),
            right: 20 + AppLayout.contentGutter(context),
            bottom: 18,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 헤더 오른쪽 아래의 "1위 / 156 PTS".
class DetailRankBlock extends StatelessWidget {
  const DetailRankBlock({
    super.key,
    required this.position,
    required this.points,
    this.note,
  });

  final int position;
  final num points;

  /// 한 줄 보조 설명("선두와 50 PTS" 등).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final white = AppColors.pureWhite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$position',
                style: AppType.largeTitle.copyWith(
                  fontSize: 40,
                  height: 1,
                  fontFeatures: AppType.tabular,
                ),
              ),
              TextSpan(
                text: '위',
                style: AppType.headline.copyWith(
                  color: white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          style: TextStyle(color: white),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatDetailPoints(points)} PTS',
          style: AppType.headline.copyWith(
            color: white,
            fontFeatures: AppType.tabular,
          ),
        ),
        if (note != null)
          Text(
            note!,
            style: AppType.caption.copyWith(
              color: white.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

/// 섹션 = 카드 밖 제목 + 내용(iOS 그룹 목록 방식, 홈 순위 섹션과 같은 규칙).
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppType.title.copyWith(
                      fontSize: 20,
                      color: AppColors.white,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 성적 한 줄: 우승 · 포디움 · 최고 · DNF. 색 아이콘 상자 없이 숫자만 크게.
class DetailStatStrip extends StatelessWidget {
  const DetailStatStrip({super.key, required this.summary});

  final SeasonSummary summary;

  @override
  Widget build(BuildContext context) {
    final best = summary.bestFinish;
    final items = [
      ('${summary.wins}', '우승'),
      ('${summary.podiums}', '포디움'),
      (best == null ? '—' : 'P$best', '최고 순위'),
      ('${summary.dnfs}', 'DNF'),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, (value, label)) in items.indexed) ...[
              if (index > 0)
                VerticalDivider(
                  width: 0.5,
                  thickness: 0.5,
                  color: AppColors.border,
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      value,
                      style: AppType.title.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: AppType.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 시즌 포인트 상세 카드: 총점 + 레이스/스프린트 분할 막대, 아래에 득점 경기·
/// 경기당 평균·최고 득점·폴·평균 순위 같은 세부 수치를 설정 앱식 목록으로.
/// (라운드별 막대 그래프는 사용자 피드백 2026-10 으로 뺐다 — 숫자로 바로
/// 읽히는 요약이 더 쓸모 있었다.)
class SeasonPointsCard extends StatelessWidget {
  const SeasonPointsCard({
    super.key,
    required this.totalPoints,
    required this.breakdown,
    required this.color,
  });

  /// 순위 데이터의 공식 총점(결과 합산과 다를 수 있어 표시는 이 값을 쓴다).
  final num totalPoints;
  final SeasonPointsBreakdown breakdown;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final hasSprint = b.sprintPoints > 0;
    final average = b.rounds == 0 ? null : b.total / b.rounds;
    final best = b.best;
    String place(double value) => '${value.toStringAsFixed(1)}위';

    final rows = <(String, String)>[
      if (b.rounds > 0) ('득점 경기', '${b.scoringRounds} / ${b.rounds} 라운드'),
      if (average != null) ('경기당 평균', '${average.toStringAsFixed(1)} PTS'),
      if (best != null && best.points > 0)
        (
          '최고 득점',
          '${formatDetailPoints(best.points)} PTS · '
              'R${best.race.round} ${best.race.nameKo.replaceAll(' 그랑프리', '')}',
        ),
      if (b.oneTwoFinishes != null) ('원투 피니시', '${b.oneTwoFinishes}회'),
      if (b.poles != null) ('폴 포지션', '${b.poles}회'),
      if (b.averageQualifying case final q?) ('평균 퀄리 순위', place(q)),
      if (b.averageFinish case final f?) ('평균 레이스 순위', place(f)),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatDetailPoints(totalPoints),
                      style: AppType.largeTitle.copyWith(
                        fontSize: 34,
                        color: AppColors.white,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PTS',
                      style: AppType.headline.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (hasSprint) ...[
                  const SizedBox(height: 12),
                  SplitBar(
                    left: b.racePoints,
                    right: b.sprintPoints,
                    leftColor: color,
                    rightColor: color.withValues(alpha: 0.4),
                    height: 8,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Legend(
                        color: color,
                        label: '레이스 ${formatDetailPoints(b.racePoints)}',
                      ),
                      const SizedBox(width: 16),
                      _Legend(
                        color: color.withValues(alpha: 0.4),
                        label: '스프린트 ${formatDetailPoints(b.sprintPoints)}',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          for (final (label, value) in rows) ...[
            const DetailRowDivider(),
            DetailInfoRow(label: label, value: value),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppType.subhead.copyWith(
            color: AppColors.textMuted,
            fontFeatures: AppType.tabular,
          ),
        ),
      ],
    );
  }
}

/// 설정 앱식 "라벨 ........ 값" 한 줄.
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.body.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.body.copyWith(
                color: AppColors.white,
                fontFeatures: AppType.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 라벨-값 목록 카드(프로필 등). 빈 값은 호출부에서 빼고 넘긴다.
class DetailInfoCard extends StatelessWidget {
  const DetailInfoCard({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (label, value)) in rows.indexed) ...[
            if (index > 0) const DetailRowDivider(),
            DetailInfoRow(label: label, value: value),
          ],
        ],
      ),
    );
  }
}

/// 맞대결 한 줄: "7  레이스  3" + 양쪽 비율 막대.
class HeadToHeadRow extends StatelessWidget {
  const HeadToHeadRow({
    super.key,
    required this.label,
    required this.left,
    required this.right,
    required this.leftColor,
    this.leftText,
    this.rightText,
  });

  final String label;
  final num left;
  final num right;
  final Color leftColor;

  /// 숫자 대신 보일 문구(포인트처럼 소수가 있을 때).
  final String? leftText;
  final String? rightText;

  @override
  Widget build(BuildContext context) {
    final leftWins = left > right;
    final rightWins = right > left;
    TextStyle number(bool winner) => AppType.title.copyWith(
      fontSize: 22,
      fontWeight: winner ? FontWeight.w700 : FontWeight.w500,
      color: winner ? AppColors.white : AppColors.textMuted,
      fontFeatures: AppType.tabular,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(leftText ?? '$left', style: number(leftWins)),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(rightText ?? '$right', style: number(rightWins)),
            ],
          ),
          const SizedBox(height: 8),
          SplitBar(
            left: left,
            right: right,
            leftColor: leftColor,
            rightColor: AppColors.textEnded,
          ),
        ],
      ),
    );
  }
}

/// 두 값의 비율을 한 막대에 나눠 그린다(가운데 2px 틈).
class SplitBar extends StatelessWidget {
  const SplitBar({
    super.key,
    required this.left,
    required this.right,
    required this.leftColor,
    required this.rightColor,
    this.height = 6,
  });

  final num left;
  final num right;
  final Color leftColor;
  final Color rightColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = left + right;
    // flex 는 정수라 천분율로 바꾼다. 0:0 이면 반반.
    final leftFlex = total == 0 ? 1 : (left / total * 1000).round();
    final rightFlex = total == 0 ? 1 : 1000 - leftFlex;
    final radius = BorderRadius.circular(height / 2);
    return SizedBox(
      height: height,
      // stretch: 자식 없는 색 상자는 높이를 강제하지 않으면 0 으로 눌린다.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leftFlex > 0)
            Expanded(
              flex: leftFlex,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: leftColor,
                  borderRadius: radius,
                ),
              ),
            ),
          if (leftFlex > 0 && rightFlex > 0) const SizedBox(width: 2),
          if (rightFlex > 0)
            Expanded(
              flex: rightFlex,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: rightColor,
                  borderRadius: radius,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 목록 카드 안의 인셋 구분선.
class DetailRowDivider extends StatelessWidget {
  const DetailRowDivider({super.key, this.indent = 16});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
    );
  }
}

String formatDetailPoints(num points) =>
    points == points.roundToDouble() ? points.toInt().toString() : '$points';
