import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MY DRIVER 저장 키 — 드라이버 코드(TLA, 예: 'LEC').
/// 이름 대신 코드를 저장하는 이유: 순위 데이터의 한글 표기가 바뀌어도
/// drivers.dart 매핑으로 다시 이어 붙일 수 있다.
const String myDriverPrefsKey = 'my_driver_code';

/// MY TEAM 저장 키 — 순위 데이터의 teamKo(예: '페라리'). teams.dart 와 동일 키.
const String myTeamPrefsKey = 'my_team_ko';

/// 사용자가 고른 내 드라이버/내 팀. 둘 다 독립적으로 비어 있을 수 있다.
@immutable
class MyPicks {
  const MyPicks({this.driverCode, this.teamKo});

  /// 아무것도 고르지 않은 상태.
  static const MyPicks empty = MyPicks();

  final String? driverCode;
  final String? teamKo;

  bool get hasDriver => driverCode != null && driverCode!.isNotEmpty;
  bool get hasTeam => teamKo != null && teamKo!.isNotEmpty;

  MyPicks copyWith({
    String? driverCode,
    String? teamKo,
    bool clearDriver = false,
    bool clearTeam = false,
  }) {
    return MyPicks(
      driverCode: clearDriver ? null : (driverCode ?? this.driverCode),
      teamKo: clearTeam ? null : (teamKo ?? this.teamKo),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MyPicks &&
      other.driverCode == driverCode &&
      other.teamKo == teamKo;

  @override
  int get hashCode => Object.hash(driverCode, teamKo);
}

/// MY PICKS(내 드라이버·내 팀) 저장/로드. 홈 위젯 브리지
/// (fmk_home_widget_bridge)가 [load] 로 읽어 myDriver*/myTeam* 페이로드를 만든다.
///
/// [ChangeNotifier] 인 이유: 설정 화면의 미리보기 타일과 홈 위젯 갱신이 같은
/// 변경을 구독한다(저장 → notify → 브리지 update).
class MyPicksController extends ChangeNotifier {
  MyPicksController();

  MyPicks _picks = MyPicks.empty;
  bool _loaded = false;

  MyPicks get picks => _picks;
  bool get isLoaded => _loaded;

  /// 저장된 선택을 읽는다(캐시됨 — 두 번째부터는 디스크를 다시 읽지 않는다).
  Future<MyPicks> load({bool force = false}) async {
    if (_loaded && !force) return _picks;
    final prefs = await SharedPreferences.getInstance();
    final driver = prefs.getString(myDriverPrefsKey);
    final team = prefs.getString(myTeamPrefsKey);
    _picks = MyPicks(
      driverCode: (driver == null || driver.isEmpty) ? null : driver,
      teamKo: (team == null || team.isEmpty) ? null : team,
    );
    _loaded = true;
    notifyListeners();
    return _picks;
  }

  /// 내 드라이버 저장. null/빈 값이면 해제.
  Future<void> saveDriver(String? code) async {
    final normalized = code?.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(myDriverPrefsKey);
      _picks = _picks.copyWith(clearDriver: true);
    } else {
      await prefs.setString(myDriverPrefsKey, normalized);
      _picks = _picks.copyWith(driverCode: normalized);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 내 팀 저장. null/빈 값이면 해제.
  Future<void> saveTeam(String? teamKo) async {
    final normalized = teamKo?.trim();
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(myTeamPrefsKey);
      _picks = _picks.copyWith(clearTeam: true);
    } else {
      await prefs.setString(myTeamPrefsKey, normalized);
      _picks = _picks.copyWith(teamKo: normalized);
    }
    _loaded = true;
    notifyListeners();
  }

  /// 테스트용: 캐시를 비워 다음 [load] 가 디스크를 다시 읽게 한다.
  @visibleForTesting
  void resetCache() {
    _picks = MyPicks.empty;
    _loaded = false;
  }
}

final MyPicksController myPicksController = MyPicksController();
