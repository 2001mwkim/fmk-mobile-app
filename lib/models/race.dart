import 'race_session.dart';

class RaceStatus {
  const RaceStatus._();

  static const String scheduled = '예정';
  static const String inProgress = '진행중';
  static const String ended = '종료';
  static const String cancelled = '취소';

  static const Set<String> values = {scheduled, inProgress, ended, cancelled};
}

class Race {
  const Race({
    required this.id,
    required this.round,
    required this.nameKo,
    required this.nameEn,
    required this.countryKo,
    required this.cityKo,
    required this.circuitKo,
    required this.startDate,
    required this.endDate,
    required this.hasSprint,
    required this.status,
    required this.sessions,
    this.isCancelled = false,
    this.cancelNote,
  });

  final String id;
  final int round;
  final String nameKo;
  final String nameEn;
  final String countryKo;
  final String cityKo;
  final String circuitKo;
  final String startDate;
  final String endDate;
  final bool hasSprint;
  final String status;
  final List<RaceSession> sessions;
  final bool isCancelled;
  final String? cancelNote;

  /// 캘린더 행의 라운드 표기. 취소된 그랑프리는 공식 라운드 번호가 없다
  /// (F1DB 도 미집계 — 취소 GP 가 라운드를 점유하면 이후 전 라운드가
  /// 공식과 어긋난다). '취소' 상태 칩이 따로 붙으므로 여기선 대시만.
  String get roundLabel => isCancelled ? '—' : 'R$round';
}
