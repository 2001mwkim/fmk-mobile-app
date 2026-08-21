import 'package:shared_preferences/shared_preferences.dart';

import 'fmk_home_widget_bridge.dart';

const String widgetThemeModePrefsKey = 'widget_theme_mode';

/// 위젯 팔레트 정책. 기본은 dark — 앱이 다크 브랜드라 위젯도 다크가 기본이며,
/// 원하면 시스템 추종/라이트로 바꿀 수 있다. 네이티브(FmkWidgetTheme.kt)·
/// iOS(FmkTheme.swift)의 'widgetThemeMode' 키와 문자열로 수동 동기화.
enum WidgetThemeMode {
  dark('dark', '다크'),
  light('light', '라이트'),
  system('system', '시스템');

  const WidgetThemeMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static WidgetThemeMode fromStorage(String? value) {
    return WidgetThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => WidgetThemeMode.dark,
    );
  }
}

class WidgetThemeController {
  const WidgetThemeController();

  Future<WidgetThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WidgetThemeMode.fromStorage(
      prefs.getString(widgetThemeModePrefsKey),
    );
  }

  Future<void> save(WidgetThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widgetThemeModePrefsKey, mode.storageValue);
    await FmkHomeWidgetBridge.updateTheme(mode.storageValue);
  }
}

const WidgetThemeController widgetThemeController = WidgetThemeController();
