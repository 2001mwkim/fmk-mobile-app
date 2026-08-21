import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/country_flags.dart';

/// 사각 국기 아이콘(assets/flags — flag-icons 4x3, MIT).
///
/// 웹(components/CountryFlag.tsx)과 동일한 룩: 4:3 사각기 + 모서리 3px 라운드
/// + 얇은 흰색 링(rgba(255,255,255,0.14)). 이모지 국기는 기기·제조사마다
/// 룩이 제각각이라 벡터 자산으로 통일하고, 매핑 없는 국가만 이모지로 폴백.
///
/// [size] 는 국기 높이. 너비는 4:3 비율로 자동 계산(= size × 4 / 3).
class FlagIcon extends StatelessWidget {
  const FlagIcon({super.key, required this.countryKo, this.size = 18});

  final String countryKo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = getCountryFlagAsset(countryKo);
    if (asset != null) {
      final width = size * 4 / 3;
      return Container(
        width: width,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          // 웹의 shadow-[0_0_0_1px_rgba(255,255,255,0.14)] 근사.
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: SvgPicture.asset(asset, fit: BoxFit.cover),
      );
    }
    final emoji = getCountryFlag(countryKo);
    if (emoji.isEmpty) return const SizedBox.shrink();
    return Text(emoji, style: TextStyle(fontSize: size * 0.85, height: 1));
  }
}
