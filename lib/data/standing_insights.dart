import '../models/race_result.dart';
import '../models/standing_insight.dart';
import 'race_results.dart';
import 'races.dart';

List<DriverRaceForm> recentDriverResults(
  String driverKo, {
  int limit = 5,
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final source = resultsByRaceId ?? raceResultsByRaceId;
  final forms = <DriverRaceForm>[];
  for (final race in races) {
    final results = source[race.id];
    if (results == null) continue;
    final matches = results.where((entry) => entry.driverKo == driverKo);
    if (matches.isNotEmpty) {
      forms.add(DriverRaceForm(race: race, result: matches.first));
    }
  }
  return forms.reversed.take(limit).toList(growable: false);
}

List<DriverRaceForm> recentTeamResults(
  String teamKo, {
  int limit = 6,
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final source = resultsByRaceId ?? raceResultsByRaceId;
  final forms = <DriverRaceForm>[];
  for (final race in races.reversed) {
    final results = source[race.id];
    if (results == null) continue;
    for (final result in results.where((entry) => entry.teamKo == teamKo)) {
      forms.add(DriverRaceForm(race: race, result: result));
      if (forms.length == limit) return forms;
    }
  }
  return forms;
}

SeasonSummary driverSeasonSummary(
  String driverKo, {
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final results = _allResults(
    resultsByRaceId,
  ).where((entry) => entry.driverKo == driverKo);
  return _summary(results);
}

SeasonSummary teamSeasonSummary(
  String teamKo, {
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final results = _allResults(
    resultsByRaceId,
  ).where((entry) => entry.teamKo == teamKo);
  return _summary(results);
}

/// 완료된 라운드마다 [matches] 가 얻은 포인트(라운드 오름차순).
List<RoundPoints> _roundPoints(
  bool Function(RaceResultEntry) matches,
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
) {
  final source = resultsByRaceId ?? raceResultsByRaceId;
  return [
    for (final race in races)
      if (source[race.id] case final results?)
        if (results.any(matches))
          RoundPoints(
            race: race,
            points: results
                .where(matches)
                .fold<num>(0, (sum, entry) => sum + entry.points),
          ),
  ];
}

/// [driverKo] 가 [rivalKo] 보다 앞선 라운드 수. 둘 다 결과가 있는 라운드만
/// 센다. 완주(숫자 순위)는 리타이어/실격보다 앞서고, 둘 다 미완주면 제외한다.
/// 레이스 결과를 넘기면 레이스 맞대결, 퀄리 결과를 넘기면 퀄리 맞대결이 된다.
HeadToHead headToHead(
  String driverKo,
  String rivalKo, {
  required Map<String, List<RaceResultEntry>> resultsByRaceId,
}) {
  var wins = 0;
  var losses = 0;
  for (final results in resultsByRaceId.values) {
    RaceResultEntry? find(String name) {
      for (final entry in results) {
        if (entry.driverKo == name) return entry;
      }
      return null;
    }

    final mine = find(driverKo);
    final theirs = find(rivalKo);
    if (mine == null || theirs == null) continue;
    final mineClassified = int.tryParse(mine.positionLabel) != null;
    final theirsClassified = int.tryParse(theirs.positionLabel) != null;
    if (!mineClassified && !theirsClassified) continue;
    final ahead = mineClassified && theirsClassified
        ? mine.position < theirs.position
        : mineClassified;
    if (ahead) {
      wins++;
    } else {
      losses++;
    }
  }
  return HeadToHead(wins: wins, losses: losses);
}

/// 팀의 라운드별 결과(최신 라운드부터).
List<TeamRoundResult> teamSeasonResults(
  String teamKo, {
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final source = resultsByRaceId ?? raceResultsByRaceId;
  return [
    for (final race in races.reversed)
      if (source[race.id] case final results?)
        if (results.any((entry) => entry.teamKo == teamKo))
          TeamRoundResult(
            race: race,
            entries:
                results.where((entry) => entry.teamKo == teamKo).toList()
                  ..sort((a, b) => a.position.compareTo(b.position)),
          ),
  ];
}

/// 드라이버 시즌 포인트 상세. [raceResults] 는 레이스만, [championshipResults]
/// 는 스프린트 포함 — 둘의 차이가 스프린트 포인트다. [qualifyingResults] 가
/// 비어 있으면 폴·평균 퀄리는 null.
SeasonPointsBreakdown driverPointsBreakdown(
  String driverKo, {
  required Map<String, List<RaceResultEntry>> raceResults,
  required Map<String, List<RaceResultEntry>> championshipResults,
  Map<String, List<RaceResultEntry>> qualifyingResults = const {},
}) {
  bool mine(RaceResultEntry entry) => entry.driverKo == driverKo;
  final qualifying = [
    for (final results in qualifyingResults.values)
      ...results.where(mine).where(_classified),
  ];
  final finishes = [
    for (final results in raceResults.values)
      ...results.where(mine).where(_classified),
  ];
  return _breakdown(
    matches: mine,
    raceResults: raceResults,
    championshipResults: championshipResults,
    poles: qualifyingResults.isEmpty
        ? null
        : qualifying.where((entry) => entry.position == 1).length,
    averageQualifying: _average(qualifying),
    averageFinish: _average(finishes),
  );
}

/// 컨스트럭터 시즌 포인트 상세. 폴은 두 드라이버 합, 원투 피니시를 더한다.
SeasonPointsBreakdown teamPointsBreakdown(
  String teamKo, {
  required Map<String, List<RaceResultEntry>> raceResults,
  required Map<String, List<RaceResultEntry>> championshipResults,
  Map<String, List<RaceResultEntry>> qualifyingResults = const {},
}) {
  bool mine(RaceResultEntry entry) => entry.teamKo == teamKo;
  final oneTwo = raceResults.values.where((results) {
    final top = results.where((entry) => entry.position <= 2 && _classified(entry));
    return top.length == 2 && top.every(mine);
  }).length;
  return _breakdown(
    matches: mine,
    raceResults: raceResults,
    championshipResults: championshipResults,
    poles: qualifyingResults.isEmpty
        ? null
        : qualifyingResults.values
              .where(
                (results) =>
                    results.any((entry) => entry.position == 1 && mine(entry)),
              )
              .length,
    oneTwoFinishes: oneTwo,
  );
}

SeasonPointsBreakdown _breakdown({
  required bool Function(RaceResultEntry) matches,
  required Map<String, List<RaceResultEntry>> raceResults,
  required Map<String, List<RaceResultEntry>> championshipResults,
  int? poles,
  double? averageQualifying,
  double? averageFinish,
  int? oneTwoFinishes,
}) {
  final rounds = _roundPoints(matches, championshipResults);
  final racePoints = _roundPoints(
    matches,
    raceResults,
  ).fold<num>(0, (sum, round) => sum + round.points);
  final total = rounds.fold<num>(0, (sum, round) => sum + round.points);
  return SeasonPointsBreakdown(
    racePoints: racePoints,
    // 정적 폴백처럼 두 맵이 같으면 0 이 된다(스프린트 정보 없음).
    sprintPoints: total - racePoints < 0 ? 0 : total - racePoints,
    scoringRounds: rounds.where((round) => round.points > 0).length,
    rounds: rounds.length,
    best: rounds.isEmpty
        ? null
        : rounds.reduce((a, b) => b.points > a.points ? b : a),
    poles: poles,
    averageQualifying: averageQualifying,
    averageFinish: averageFinish,
    oneTwoFinishes: oneTwoFinishes,
  );
}

bool _classified(RaceResultEntry entry) =>
    int.tryParse(entry.positionLabel) != null;

double? _average(List<RaceResultEntry> entries) => entries.isEmpty
    ? null
    : entries.fold<int>(0, (sum, entry) => sum + entry.position) /
          entries.length;

SeasonSummary _summary(Iterable<RaceResultEntry> results) {
  final values = results.toList(growable: false);
  final classified = values.where((entry) => entry.positionLabel != 'DNF');
  final positions = classified.map((entry) => entry.position);
  return SeasonSummary(
    wins: values.where((entry) => entry.position == 1).length,
    podiums: values.where((entry) => entry.position <= 3).length,
    bestFinish: positions.isEmpty ? null : positions.reduce(_min),
    dnfs: values.where((entry) => entry.positionLabel == 'DNF').length,
  );
}

List<StandingTrendPoint> driverStandingTrend(
  String driverKo, {
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) => _standingTrend(
  keyFor: (entry) => entry.driverKo,
  target: driverKo,
  resultsByRaceId: resultsByRaceId,
);

List<StandingTrendPoint> teamStandingTrend(
  String teamKo, {
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) => _standingTrend(
  keyFor: (entry) => entry.teamKo,
  target: teamKo,
  resultsByRaceId: resultsByRaceId,
);

List<StandingTrendPoint> _standingTrend({
  required String Function(RaceResultEntry) keyFor,
  required String target,
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
}) {
  final source = resultsByRaceId ?? raceResultsByRaceId;
  final records = <String, _ChampionshipRecord>{};
  final trend = <StandingTrendPoint>[];
  final completedRaces =
      races.where((race) => source.containsKey(race.id)).toList()
        ..sort((a, b) => a.round.compareTo(b.round));

  for (final race in completedRaces) {
    for (final result in source[race.id]!) {
      final key = keyFor(result);
      final record = records.putIfAbsent(key, _ChampionshipRecord.new);
      record
        ..points += result.points
        ..addFinish(result.position);
    }
    if (!records.containsKey(target)) continue;
    final order = records.entries.toList()
      ..sort((a, b) {
        final championshipOrder = a.value.compareForStandings(b.value);
        return championshipOrder != 0
            ? championshipOrder
            : a.key.compareTo(b.key);
      });
    trend.add(
      StandingTrendPoint(
        round: race.round,
        position: order.indexWhere((entry) => entry.key == target) + 1,
      ),
    );
  }
  return trend;
}

/// 누적 포인트가 같으면 F1 챔피언십 방식대로 우승 횟수, 2위 횟수,
/// 3위 횟수 … 순으로 비교한다. 모든 성적까지 같을 때만 안정적인 표시를
/// 위해 호출부가 이름순 fallback을 사용한다.
class _ChampionshipRecord {
  num points = 0;
  final Map<int, int> _finishes = {};

  void addFinish(int position) {
    if (position < 1) return;
    _finishes.update(position, (count) => count + 1, ifAbsent: () => 1);
  }

  int compareForStandings(_ChampionshipRecord other) {
    final pointsOrder = other.points.compareTo(points);
    if (pointsOrder != 0) return pointsOrder;

    final thisWorst = _finishes.keys.fold(0, _max);
    final otherWorst = other._finishes.keys.fold(0, _max);
    final lastPosition = _max(thisWorst, otherWorst);
    for (var position = 1; position <= lastPosition; position++) {
      final finishOrder = (other._finishes[position] ?? 0).compareTo(
        _finishes[position] ?? 0,
      );
      if (finishOrder != 0) return finishOrder;
    }
    return 0;
  }
}

Iterable<RaceResultEntry> _allResults(
  Map<String, List<RaceResultEntry>>? resultsByRaceId,
) sync* {
  for (final results in (resultsByRaceId ?? raceResultsByRaceId).values) {
    yield* results;
  }
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;
