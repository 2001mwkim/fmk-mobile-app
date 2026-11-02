import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fmk_app/services/app_theme_controller.dart';
import 'package:fmk_app/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // 다른 테스트 파일이 다크 기본 팔레트를 전제하므로 반드시 되돌린다.
    appThemeController.resetForTest();
  });

  test('저장값이 없거나 이상하면 다크가 기본이다', () {
    expect(AppThemeMode.fromStorage(null), AppThemeMode.dark);
    expect(AppThemeMode.fromStorage('nope'), AppThemeMode.dark);
    expect(AppThemeMode.fromStorage('light'), AppThemeMode.light);
    expect(AppThemeMode.fromStorage('fmk'), AppThemeMode.fmk);
  });

  // 2026-10 디자인 정리로 다크 팔레트를 iOS 시스템 다크 계열로 옮겼다
  // (이전엔 웹 Tailwind 원본값과 비트 동일을 강제했다). 핵심 면 값이 의도치
  // 않게 바뀌지 않도록 고정해 둔다.
  test('기본 다크 팔레트는 순검정 배경 + 무채색 카드 + systemRed 다', () {
    appThemeController.resetForTest();
    expect(AppColors.background, const Color(0xFF000000));
    expect(AppColors.card, const Color(0xFF1C1C1E));
    expect(AppColors.red, const Color(0xFFFF453A));
    expect(AppColors.white, const Color(0xFFFFFFFF));
    expect(AppColors.textMuted, const Color(0xFF8E8E93));
    expect(AppColors.heroAccent, AppColors.red);
  });

  test('save 는 팔레트를 즉시 바꾸고 prefs 에 저장한다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await appThemeController.save(AppThemeMode.fmk);

    // FMK: 액센트는 옐로, 배경은 순검정, 옐로 위 텍스트는 검정.
    expect(AppColors.red, const Color(0xFFFFD200));
    expect(AppColors.background, const Color(0xFF000000));
    expect(AppColors.onAccent, const Color(0xFF000000));
    // 의미색은 테마와 무관하게 고정.
    expect(AppColors.tyreSoft, const Color(0xFFF87171));
    expect(AppColors.flagRed, const Color(0xFFEF4444));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appThemeModePrefsKey), 'fmk');
  });

  test('load 는 저장된 테마를 복원한다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      appThemeModePrefsKey: 'light',
    });
    await appThemeController.load();
    expect(appThemeController.mode, AppThemeMode.light);
    expect(AppColors.brightness, Brightness.light);
    // 라이트: 최상위 텍스트는 잉크색, 진짜 흰색은 pureWhite 로만.
    expect(AppColors.white, isNot(AppColors.pureWhite));
  });

  test('설정 화면 복원 플래그는 1회성이다', () {
    appThemeController.markReopenSettings();
    expect(appThemeController.consumeReopenSettings(), isTrue);
    expect(appThemeController.consumeReopenSettings(), isFalse);
  });
}
