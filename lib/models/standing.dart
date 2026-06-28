class DriverStanding {
  const DriverStanding({
    required this.position,
    required this.driverKo,
    required this.driverEn,
    required this.teamKo,
    required this.teamEn,
    required this.points,
    this.note,
  });

  final int position;
  final String driverKo;
  final String driverEn;
  final String teamKo;
  final String teamEn;
  final num points;
  final String? note;
}

class ConstructorStanding {
  const ConstructorStanding({
    required this.position,
    required this.teamKo,
    required this.teamEn,
    required this.points,
    this.note,
  });

  final int position;
  final String teamKo;
  final String teamEn;
  final num points;
  final String? note;
}
