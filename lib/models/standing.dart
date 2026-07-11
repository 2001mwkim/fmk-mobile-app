class DriverStanding {
  const DriverStanding({
    required this.position,
    required this.driverKo,
    required this.driverEn,
    required this.teamKo,
    required this.teamEn,
    required this.points,
    this.positionChange,
    this.note,
  });

  final int position;
  final String driverKo;
  final String driverEn;
  final String teamKo;
  final String teamEn;
  final num points;
  final int? positionChange;
  final String? note;

  /// 서버 /api/standings JSON 파싱. 필수 필드가 깨져 있으면 null(항목 skip).
  static DriverStanding? fromJson(Map<String, dynamic> json) {
    final position = json['position'];
    final driverKo = json['driverKo'];
    final points = json['points'];
    if (position is! int ||
        driverKo is! String ||
        driverKo.isEmpty ||
        points is! num) {
      return null;
    }
    return DriverStanding(
      position: position,
      driverKo: driverKo,
      driverEn: json['driverEn'] is String ? json['driverEn'] as String : '',
      teamKo: json['teamKo'] is String ? json['teamKo'] as String : '',
      teamEn: json['teamEn'] is String ? json['teamEn'] as String : '',
      points: points,
      positionChange: json['positionChange'] is int
          ? json['positionChange'] as int
          : null,
    );
  }
}

class ConstructorStanding {
  const ConstructorStanding({
    required this.position,
    required this.teamKo,
    required this.teamEn,
    required this.points,
    this.positionChange,
    this.note,
  });

  final int position;
  final String teamKo;
  final String teamEn;
  final num points;
  final int? positionChange;
  final String? note;

  /// 서버 /api/standings JSON 파싱. 필수 필드가 깨져 있으면 null(항목 skip).
  static ConstructorStanding? fromJson(Map<String, dynamic> json) {
    final position = json['position'];
    final teamKo = json['teamKo'];
    final points = json['points'];
    if (position is! int ||
        teamKo is! String ||
        teamKo.isEmpty ||
        points is! num) {
      return null;
    }
    return ConstructorStanding(
      position: position,
      teamKo: teamKo,
      teamEn: json['teamEn'] is String ? json['teamEn'] as String : '',
      points: points,
      positionChange: json['positionChange'] is int
          ? json['positionChange'] as int
          : null,
    );
  }
}
