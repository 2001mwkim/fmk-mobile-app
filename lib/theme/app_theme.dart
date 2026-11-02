import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const String fontFamily = 'Pretendard';

  /// 현재 선택된 팔레트(AppColors.palette)로 ThemeData 를 만든다.
  /// 테마 전환 시 app.dart 가 이 함수를 다시 불러 MaterialApp 을 리빌드한다.
  /// AppColors 가 getter 라 내부에 const 위젯 테마를 둘 수 없음에 주의.
  static ThemeData current() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.red,
      brightness: AppColors.brightness,
      primary: AppColors.red,
      surface: AppColors.card,
    );

    final baseText = TextStyle(
      fontFamily: fontFamily,
      color: AppColors.white,
      leadingDistribution: TextLeadingDistribution.even,
    );
    // 2026-10 디자인 정리: 굵기는 w700 이하로 낮추고 크기는 AppType 스케일에
    // 맞췄다(이전 값은 w800 위주라 화면 전체가 같은 무게로 소리쳤다).
    final textTheme = TextTheme(
      displaySmall: baseText.merge(AppType.largeTitle),
      headlineMedium: baseText.merge(AppType.largeTitle),
      titleLarge: baseText.merge(AppType.title),
      titleMedium: baseText.merge(AppType.headline),
      bodyLarge: baseText.merge(AppType.body),
      bodyMedium: baseText
          .merge(AppType.subhead)
          .copyWith(fontWeight: FontWeight.w400, color: AppColors.textMuted),
      bodySmall: baseText
          .merge(AppType.caption)
          .copyWith(fontWeight: FontWeight.w400, color: AppColors.textMuted),
      labelLarge: baseText.merge(AppType.subhead),
      labelMedium: baseText
          .merge(AppType.caption)
          .copyWith(color: AppColors.textMuted),
      labelSmall: baseText
          .merge(AppType.caption)
          .copyWith(color: AppColors.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.brightness,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      // 머티리얼 물결(ripple) 대신 눌린 동안만 면이 살짝 밝아지는 iOS 식
      // 피드백. 물결이 카드 전체로 퍼지는 효과가 웹 이식 앱 인상을 키웠다.
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.white.withValues(alpha: 0.06),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // 하단 네비는 widgets/bottom_nav.dart 의 커스텀 위젯이 담당.
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        // 테두리 없이 배경 명도 차이로만 면을 나눈다(AppCard 와 동일).
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 0.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.red),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.redSoft,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 이전 이름 호환(테마 도입 전 유일한 진입점). 새 코드는 current() 사용.
  static ThemeData dark() => current();
}
