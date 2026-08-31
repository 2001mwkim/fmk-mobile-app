import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

const String appThemeModePrefsKey = 'app_theme_mode';

/// 앱 내부 색 테마. 위젯 테마(widget_theme_controller)와는 별개다 —
/// 홈 위젯/워치는 네이티브 팔레트를 따로 갖고 있어 이 설정의 영향을 받지 않는다.
/// 기본은 dark(기존 디자인 그대로).
enum AppThemeMode {
  dark(AppThemeId.dark, 'dark', '다크'),
  light(AppThemeId.light, 'light', '라이트'),
  // 라벨은 '포매코' — 팔로워들이 쓰는 포뮬러 매거진 코리아 애칭(FMK 는 잘 안 씀).
  // 저장 문자열 'fmk' 와 코드 식별자는 그대로 둔다.
  fmk(AppThemeId.fmk, 'fmk', '포매코');

  const AppThemeMode(this.id, this.storageValue, this.label);

  final AppThemeId id;
  final String storageValue;
  final String label;

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppThemeMode.dark,
    );
  }
}

/// 테마 로드/저장 + 전환 알림. AppColors.palette 교체는 여기서만 한다.
/// mode 가 바뀌면 앱 루트(app.dart)가 notifier 로 MaterialApp 을 리빌드한다.
class AppThemeController {
  AppThemeController();

  final ValueNotifier<AppThemeMode> notifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.dark);

  AppThemeMode get mode => notifier.value;

  /// 부팅 시 runApp 전에 1회 호출 — 첫 프레임부터 저장된 테마로 그린다.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apply(AppThemeMode.fromStorage(prefs.getString(appThemeModePrefsKey)));
  }

  Future<void> save(AppThemeMode mode) async {
    _apply(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appThemeModePrefsKey, mode.storageValue);
  }

  void _apply(AppThemeMode mode) {
    AppColors.palette = AppPalette.of(mode.id);
    notifier.value = mode;
  }

  /// 테마 전환은 MaterialApp 을 키 교체로 리마운트하므로 내비게이션 스택이
  /// 사라진다. 설정 화면에서 전환한 경우 리마운트 직후 설정 화면을 무애니메이션
  /// 으로 복원하기 위한 1회성 플래그(설정 카드가 set, MainShell 이 consume).
  bool _reopenSettings = false;

  void markReopenSettings() => _reopenSettings = true;

  bool consumeReopenSettings() {
    final value = _reopenSettings;
    _reopenSettings = false;
    return value;
  }

  /// 테스트 전용 — prefs 를 건드리지 않고 팔레트만 되돌린다.
  @visibleForTesting
  void resetForTest() {
    _reopenSettings = false;
    _apply(AppThemeMode.dark);
  }
}

final AppThemeController appThemeController = AppThemeController();
