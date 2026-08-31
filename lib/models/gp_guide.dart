/// 그랑프리 상세의 "관전 가이드" 데이터 모델.
///
/// 데이터는 lib/data/gp_guides.dart 에 raceId 별 정적 큐레이션으로 존재한다
/// (시즌 중 갱신 빈도가 낮아 서버 경유 없이 번들에 담는다).
class GpGuide {
  const GpGuide({
    this.tyres,
    this.lapRecord,
    this.recentWinners = const <GpWinner>[],
    this.traits,
    this.watchPoints = const <String>[],
  });

  /// 피렐리 발표 컴파운드 할당. 미발표(시즌 후반)면 null.
  final TyreAllocation? tyres;

  /// 결승 레이스 랩 레코드(퀄리 기록 아님). 신규 서킷이면 null.
  final GpLapRecord? lapRecord;

  /// 최근 시즌 우승자(최신 연도 먼저). 신규 서킷이면 빈 목록.
  final List<GpWinner> recentWinners;

  /// 서킷 성격 게이지(1~5).
  final GpTraits? traits;

  /// 경기를 보는 데 도움이 되는 짧은 관전 포인트(한국어 큐레이션).
  final List<String> watchPoints;
}

/// 피렐리 컴파운드 할당 — C1(최경질)~C5(최연질) 중 3종.
class TyreAllocation {
  const TyreAllocation({
    required this.hard,
    required this.medium,
    required this.soft,
  });

  final String hard; // 예: 'C1'
  final String medium; // 예: 'C2'
  final String soft; // 예: 'C3'
}

class GpLapRecord {
  const GpLapRecord({
    required this.time,
    required this.driverKo,
    required this.year,
  });

  final String time; // 예: '1:19.813'
  final String driverKo; // 예: '샤를 르클레르'
  final int year;
}

class GpWinner {
  const GpWinner({
    required this.year,
    required this.driverKo,
    required this.teamKo,
  });

  final int year;
  final String driverKo;
  final String teamKo;
}

/// 1(낮음/적음) ~ 5(높음/많음). 추월 난이도는 5 가 "매우 어려움".
class GpTraits {
  const GpTraits({
    required this.downforce,
    required this.tyreStress,
    required this.overtaking,
  });

  final int downforce;
  final int tyreStress;
  final int overtaking;
}
