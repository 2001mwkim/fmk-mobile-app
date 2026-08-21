import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fmk_app/services/widget_theme_controller.dart';

// 위젯 팔레트 컨트롤러. 기본값 dark, save 는 prefs 기록 + 네이티브 갱신
// (FmkHomeWidgetBridge.updateTheme 은 테스트 환경에선 미지원 플랫폼이라 no-op).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('기본값은 다크', () async {
    expect(await widgetThemeController.load(), WidgetThemeMode.dark);
  });

  test('알 수 없는 값은 다크로 폴백', () async {
    SharedPreferences.setMockInitialValues({widgetThemeModePrefsKey: 'bogus'});
    expect(await widgetThemeController.load(), WidgetThemeMode.dark);
  });

  test('저장한 모드를 다시 읽는다', () async {
    await widgetThemeController.save(WidgetThemeMode.light);
    expect(await widgetThemeController.load(), WidgetThemeMode.light);

    await widgetThemeController.save(WidgetThemeMode.system);
    expect(await widgetThemeController.load(), WidgetThemeMode.system);
  });

  test('save 는 prefs 에 storageValue 를 쓴다', () async {
    await widgetThemeController.save(WidgetThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(widgetThemeModePrefsKey), 'light');
  });
}
