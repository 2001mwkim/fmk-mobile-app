import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Pretendard';

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: Brightness.dark,
      primary: AppColors.red,
      surface: AppColors.card,
    );

    const baseText = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.white,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final textTheme = TextTheme(
      displaySmall: baseText.copyWith(
        fontSize: 30,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineMedium: baseText.copyWith(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: baseText.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: baseText.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: baseText.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: baseText.copyWith(
        fontSize: 13,
        height: 1.5,
        color: AppColors.textMuted,
      ),
      bodySmall: baseText.copyWith(
        fontSize: 12,
        height: 1.45,
        color: AppColors.textMuted,
      ),
      labelLarge: baseText.copyWith(fontSize: 13, height: 1.25),
      labelMedium: baseText.copyWith(
        fontSize: 11,
        height: 1.3,
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: baseText.copyWith(
        fontSize: 11,
        height: 1.3,
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // 하단 네비는 widgets/bottom_nav.dart 의 커스텀 위젯이 담당.
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        // 웹 Card.tsx rounded-2xl + border-white/10
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.red,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.redSoft,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
