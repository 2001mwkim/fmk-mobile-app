import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/country_flags.dart';

/// 원형 국기 아이콘(assets/flags — circle-flags, MIT).
///
/// 이모지 국기는 기기·제조사마다 룩이 제각각이라(삼성/픽셀/구형 기기)
/// 벡터 자산으로 통일한다. 매핑이 없는 국가만 이모지로 폴백.
class FlagIcon extends StatelessWidget {
  const FlagIcon({super.key, required this.countryKo, this.size = 18});

  final String countryKo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = getCountryFlagAsset(countryKo);
    if (asset != null) {
      return SvgPicture.asset(asset, width: size, height: size);
    }
    final emoji = getCountryFlag(countryKo);
    if (emoji.isEmpty) return const SizedBox.shrink();
    return Text(emoji, style: TextStyle(fontSize: size * 0.85, height: 1));
  }
}
