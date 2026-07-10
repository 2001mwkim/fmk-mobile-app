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

  /// 서버 /api/race-results JSON 파싱. 필수 필드가 깨져 있으면 null(항목 skip).
  /// 서버가 주는 driverNumber/driverCode/timeOrStatus 등 추가 필드는 무시한다.
  static RaceResultEntry? fromJson(Map<String, dynamic> json) {
    final position = json['position'];
    final driverKo = json['driverKo'];
    final points = json['points'];
    if (position is! int || driverKo is! String || driverKo.isEmpty || points is! num) {
      return null;
    }
    return RaceResultEntry(
      position: position,
      positionLabel: json['positionLabel'] is String
          ? json['positionLabel'] as String
          : '$position',
      driverKo: driverKo,
      driverEn: json['driverEn'] is String ? json['driverEn'] as String : '',
      teamKo: json['teamKo'] is String ? json['teamKo'] as String : '',
      teamEn: json['teamEn'] is String ? json['teamEn'] as String : '',
      points: points,
      time: json['time'] is String ? json['time'] as String : null,
      gap: json['gap'] is String ? json['gap'] as String : null,
    );
  }
}
