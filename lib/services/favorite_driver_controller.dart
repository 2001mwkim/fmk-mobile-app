import 'package:shared_preferences/shared_preferences.dart';

/// 최애 드라이버(홈 위젯용)로 저장하는 shared_preferences 키.
/// 드라이버 한글 이름(driverKo)을 저장한다 — 순위 데이터의 행과 이름으로
/// 매칭한다. 브리지(fmk_home_widget_bridge)가 이 키를 직접 읽어 위젯
/// 페이로드(favDriver*)를 만든다.
const String favoriteDriverPrefsKey = 'favorite_driver_ko';

/// 최애 드라이버 선택을 저장/로드한다. 값은 드라이버 한글 이름.
class FavoriteDriverController {
  const FavoriteDriverController();

  /// 저장된 최애 드라이버 이름. 없거나 빈 값이면 null.
  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(favoriteDriverPrefsKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  /// [driverKo] 를 저장한다. null/빈 값이면 선택 해제.
  Future<void> save(String? driverKo) async {
    final prefs = await SharedPreferences.getInstance();
    if (driverKo == null || driverKo.isEmpty) {
      await prefs.remove(favoriteDriverPrefsKey);
    } else {
      await prefs.setString(favoriteDriverPrefsKey, driverKo);
    }
  }
}

const FavoriteDriverController favoriteDriverController =
    FavoriteDriverController();
