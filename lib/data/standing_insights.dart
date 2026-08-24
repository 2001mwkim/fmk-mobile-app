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
