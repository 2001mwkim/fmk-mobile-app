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
}
