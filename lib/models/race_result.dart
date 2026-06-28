class RaceResultEntry {
  const RaceResultEntry({
    required this.position,
    required this.positionLabel,
    required this.driverKo,
    required this.driverEn,
    required this.teamKo,
    required this.teamEn,
    required this.points,
    this.time,
    this.gap,
  });

  final int position;
  final String positionLabel;
  final String driverKo;
  final String driverEn;
  final String teamKo;
  final String teamEn;
  final num points;
  final String? time;
  final String? gap;
}
