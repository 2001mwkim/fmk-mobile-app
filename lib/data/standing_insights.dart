import '../models/race_result.dart';
import '../models/standing_insight.dart';
import 'race_results.dart';
import 'races.dart';

List<DriverRaceForm> recentDriverResults(String driverKo, {int limit = 5}) {
  final forms = <DriverRaceForm>[];
  for (final race in races) {
    final results = raceResultsByRaceId[race.id];
    if (results == null) continue;
    final matches = results.where((entry) => entry.driverKo == driverKo);
    if (matches.isNotEmpty) {
      forms.add(DriverRaceForm(race: race, result: matches.first));
    }
  }
  return forms.reversed.take(limit).toList(growable: false);
}

List<DriverRaceForm> recentTeamResults(String teamKo, {int limit = 6}) {
  final forms = <DriverRaceForm>[];
  for (final race in races.reversed) {
    final results = raceResultsByRaceId[race.id];
    if (results == null) continue;
    for (final result in results.where((entry) => entry.teamKo == teamKo)) {
      forms.add(DriverRaceForm(race: race, result: result));
      if (forms.length == limit) return forms;
    }
  }
  return forms;
}

SeasonSummary driverSeasonSummary(String driverKo) {
  final results = _allResults.where((entry) => entry.driverKo == driverKo);
  return _summary(results);
}

SeasonSummary teamSeasonSummary(String teamKo) {
  final results = _allResults.where((entry) => entry.teamKo == teamKo);
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

List<StandingTrendPoint> driverStandingTrend(String driverKo) =>
    _standingTrend(keyFor: (entry) => entry.driverKo, target: driverKo);

List<StandingTrendPoint> teamStandingTrend(String teamKo) =>
    _standingTrend(keyFor: (entry) => entry.teamKo, target: teamKo);

List<StandingTrendPoint> _standingTrend({
  required String Function(RaceResultEntry) keyFor,
  required String target,
}) {
  final points = <String, num>{};
  final trend = <StandingTrendPoint>[];
  final completedRaces =
      races.where((race) => raceResultsByRaceId.containsKey(race.id)).toList()
        ..sort((a, b) => a.round.compareTo(b.round));

  for (final race in completedRaces) {
    for (final result in raceResultsByRaceId[race.id]!) {
      final key = keyFor(result);
      points[key] = (points[key] ?? 0) + result.points;
    }
    if (!points.containsKey(target)) continue;
    final order = points.entries.toList()
      ..sort((a, b) {
        final score = b.value.compareTo(a.value);
        return score != 0 ? score : a.key.compareTo(b.key);
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

Iterable<RaceResultEntry> get _allResults sync* {
  for (final results in raceResultsByRaceId.values) {
    yield* results;
  }
}

int _min(int a, int b) => a < b ? a : b;
