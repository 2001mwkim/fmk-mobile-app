import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 웹 components/Chip.tsx 의 variant 와 1:1 대응.
enum AppChipVariant { red, blue, neutral, mono, ended }

/// 웹 components/Chip.tsx 의 Flutter 포팅.
///
/// 공통: inline-flex items-center px-2 py-1 text-[10px] font-bold leading-none
///   => 패딩 H8/V4, 글자 10px, bold
///
/// variant 별 (웹 그대로):
///   red     rounded-full bg-red-500/15  text-red-400
///   blue    rounded-full bg-blue-500/15 text-blue-400
///   neutral rounded-full bg-white/[0.06] text-[#959bb6]
///   mono    rounded-md   bg-white/[0.07] text-slate-300
///   ended   rounded-full bg-white/[0.04] text-[#5b6178]
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.neutral,
  });

  final String label;
  final AppChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(variant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(spec.isPill ? 999 : 6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          height: 1, // leading-none
          fontWeight: FontWeight.bold,
          color: spec.foreground,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }

  static _ChipSpec _specFor(AppChipVariant variant) {
    switch (variant) {
      case AppChipVariant.red:
        return const _ChipSpec(
          background: Color(0x26EF4444), // red-500 / 15%
          foreground: AppColors.redSoft, // red-400
        );
      case AppChipVariant.blue:
        return const _ChipSpec(
          background: Color(0x263B82F6), // blue-500 / 15%
          foreground: AppColors.blueSoft, // blue-400
        );
      case AppChipVariant.neutral:
        return const _ChipSpec(
          background: AppColors.faintBorder, // white / 6%
          foreground: AppColors.textMuted,
        );
      case AppChipVariant.mono:
        return const _ChipSpec(
          background: AppColors.divider, // white / 7%
          foreground: AppColors.slate300,
          isPill: false,
        );
      case AppChipVariant.ended:
        return const _ChipSpec(
          background: Color(0x0AFFFFFF), // white / 4%
          foreground: AppColors.textEnded,
        );
    }
  }
}

class _ChipSpec {
  const _ChipSpec({
    required this.background,
    required this.foreground,
    this.isPill = true,
  });

  final Color background;
  final Color foreground;
  final bool isPill;
}
