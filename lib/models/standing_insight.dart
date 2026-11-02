import 'race.dart';
import 'race_result.dart';

class StandingTrendPoint {
  const StandingTrendPoint({required this.round, required this.position});

  final int round;
  final int position;
}

class DriverRaceForm {
  const DriverRaceForm({required this.race, required this.result});

  final Race race;
  final RaceResultEntry result;
}

class SeasonSummary {
  const SeasonSummary({
    required this.wins,
    required this.podiums,
    required this.bestFinish,
    required this.dnfs,
  });

  final int wins;
  final int podiums;
  final int? bestFinish;
  final int dnfs;
}

/// 한 라운드에서 얻은 챔피언십 포인트(스프린트 포함). 라운드별 막대 그래프용.
class RoundPoints {
  const RoundPoints({required this.race, required this.points});

  final Race race;
  final num points;
}

/// 팀메이트 맞대결 집계. [wins] 는 기준 드라이버가 앞선 횟수.
class HeadToHead {
  const HeadToHead({required this.wins, required this.losses});

  final int wins;
  final int losses;

  int get total => wins + losses;
}

/// 한 라운드의 팀 결과(두 드라이버 + 합산 포인트). 컨스트럭터 시즌 결과 목록용.
class TeamRoundResult {
  const TeamRoundResult({required this.race, required this.entries});

  final Race race;

  /// 순위 오름차순.
  final List<RaceResultEntry> entries;

  num get points => entries.fold<num>(0, (sum, entry) => sum + entry.points);
}

/// 시즌 포인트 상세(상세 화면 '시즌 포인트' 카드).
class SeasonPointsBreakdown {
  const SeasonPointsBreakdown({
    required this.racePoints,
    required this.sprintPoints,
    required this.scoringRounds,
    required this.rounds,
    required this.best,
    this.poles,
    this.averageQualifying,
    this.averageFinish,
    this.oneTwoFinishes,
  });

  final num racePoints;
  final num sprintPoints;

  /// 포인트를 딴 라운드 수 / 결과가 있는 라운드 수.
  final int scoringRounds;
  final int rounds;

  /// 가장 많이 딴 라운드(결과가 없으면 null).
  final RoundPoints? best;

  /// 퀄리 결과가 없으면(정적 폴백) null — 화면은 그 줄을 숨긴다.
  final int? poles;
  final double? averageQualifying;

  /// 완주한 레이스의 평균 순위.
  final double? averageFinish;

  /// 컨스트럭터 전용: 두 드라이버 1·2위 동시 피니시 횟수.
  final int? oneTwoFinishes;

  num get total => racePoints + sprintPoints;
}
