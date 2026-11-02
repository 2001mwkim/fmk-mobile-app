import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/country_flags.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'glass.dart';

/// 홈 "다음 그랑프리" 히어로 표면.
///
/// 이전엔 레드 테두리로 다른 카드와 구분했지만, 히어로는 이미 맨 위·가장 큰
/// 카드라 위치와 크기만으로 주인공이 된다. 2026-10 디자인 정리에서 레드를
/// '진행 중' 의미에만 쓰기로 하면서 테두리를 걷었고, 대신 [ambientCountryKo]
/// 의 국기를 크게 흐려 카드 위쪽에 그 나라 색이 은은하게 번지게 한다(애플
/// 뮤직이 앨범 아트를 배경에 번지게 하는 방식). GP 마다 히어로 색이 달라져
/// 무채색 앱에 온기가 생기고, 위에 얹는 글래스 타일이 비칠 배경도 된다.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.ambientCountryKo,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 탭 시 동작(예: 상세 이동). null 이면 비탭(시각 변화 없음).
  final VoidCallback? onTap;

  /// 배경에 번지게 할 국기의 국가(한글명). 벡터 국기가 없으면 무시.
  final String? ambientCountryKo;

  static const BorderRadius _radius = AppRadius.cardBorder;

  @override
  Widget build(BuildContext context) {
    final asset = ambientCountryKo == null
        ? null
        : getCountryFlagAsset(ambientCountryKo!);
    final light = AppColors.brightness == Brightness.light;

    final surface = ClipRRect(
      borderRadius: _radius,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: AppColors.card)),
          if (asset != null)
            Positioned.fill(
              child: _AmbientFlag(asset: asset, opacity: light ? 0.30 : 0.50),
            ),
          // 국기 위 얇은 어둠막 — 흰 줄무늬(멕시코·일본 등)가 그대로 비치면
          // 그 위 글씨가 묻힌다(사용자 피드백 2026-10).
          if (asset != null)
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.card.withValues(alpha: light ? 0.15 : 0.30),
              ),
            ),
          // 아래쪽은 카드 색으로 되돌려 세션 목록 가독성을 지킨다.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.55, 0.85],
                  colors: [
                    AppColors.card.withValues(alpha: 0.05),
                    AppColors.card.withValues(alpha: 0.75),
                    AppColors.card,
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );

    return AppPressable(onTap: onTap, pressedScale: 0.985, child: surface);
  }
}

/// 국기를 카드보다 조금 키워 흐린 배경. 가장자리가 투명하게 빠지지 않도록
/// 확대하고, 위쪽에 몰리게 정렬한다.
class _AmbientFlag extends StatelessWidget {
  const _AmbientFlag({required this.asset, required this.opacity});

  final String asset;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          // 너무 세게 흐리면 줄무늬 국기 색이 한데 섞여 탁해진다(벨기에 →
          // 갈색). 색면이 각각 살아 있는 정도로만 흐린다.
          sigmaX: 26,
          sigmaY: 26,
          tileMode: TileMode.decal,
        ),
        child: Transform.scale(
          scale: 1.25,
          alignment: Alignment.topCenter,
          child: SvgPicture.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}

/// 히어로(국기 앰비언트) 위 보조 텍스트색. 회색 대신 최상위 텍스트색을
/// 반투명하게 써서 배경 색이 무엇이든 명도 대비가 유지되게 한다.
Color heroSecondaryText() => AppColors.white.withValues(alpha: 0.78);
