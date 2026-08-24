/// 서버의 최신 참가 기록이 시즌 전체의 현재 소속처럼 섞여 들어오는 경우를
/// 보정하는 앱 측 드라이버 소속 규칙.
///
/// 리암 로슨은 2026 네덜란드 GP에서만 레드불 레이싱으로 출전했고, 그 외
/// 화면(챔피언십 순위 포함)에서는 레이싱 불스 소속으로 표시한다.
const String kLawsonRedBullRaceId = 'netherlands-2026';

typedef DriverTeamAssignment = ({String teamKo, String teamEn});

DriverTeamAssignment? fixedDriverTeamAssignment({
  required String driverKo,
  required String driverEn,
  String? raceId,
}) {
  final isLiamLawson =
      driverKo.trim() == '리암 로슨' ||
      driverEn.trim().toLowerCase() == 'liam lawson';
  if (!isLiamLawson) return null;

  if (raceId == kLawsonRedBullRaceId) {
    return (teamKo: '레드불 레이싱', teamEn: 'Red Bull Racing');
  }
  return (teamKo: '레이싱 불스', teamEn: 'Racing Bulls');
}
