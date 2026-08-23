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
