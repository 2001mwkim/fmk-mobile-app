import 'dart:convert';

/// 투표 종류 — collector `scripts/polls.ts` 의 kind 와 같은 문자열.
enum PollKind {
  winner('winner'),
  pole('pole'),
  rating('rating');

  const PollKind(this.wire);
  final String wire;
}

/// 우승·폴 예측 집계.
class PickTally {
  const PickTally({
    required this.open,
    required this.total,
    required this.counts,
    this.closesAt,
  });

  final bool open;
  final DateTime? closesAt;
  final int total;

  /// TLA → 표 수(많은 순).
  final Map<String, int> counts;

  /// 득표율 상위 [limit]개 (TLA, 0~1).
  List<(String, double)> top(int limit) {
    if (total <= 0) return const [];
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries.take(limit)) (entry.key, entry.value / total),
    ];
  }
}

/// 레이스 평점(1~5) 집계.
class RatingTally {
  const RatingTally({
    required this.open,
    required this.total,
    required this.histogram,
    this.average,
    this.opensAt,
    this.closesAt,
  });

  final bool open;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int total;
  final double? average;

  /// 인덱스 0 = 1점.
  final List<int> histogram;
}

/// collector `GET /polls.json?raceId=` 응답.
class RacePoll {
  const RacePoll({
    required this.raceId,
    required this.winner,
    required this.pole,
    required this.rating,
  });

  final String raceId;
  final PickTally winner;
  final PickTally pole;
  final RatingTally rating;

  static RacePoll? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final poll = decoded['poll'] is Map ? decoded['poll'] as Map : decoded;
      final raceId = poll['raceId'];
      if (raceId is! String) return null;
      return RacePoll(
        raceId: raceId,
        winner: _pick(poll['winner']),
        pole: _pick(poll['pole']),
        rating: _rating(poll['rating']),
      );
    } catch (_) {
      return null;
    }
  }

  static PickTally _pick(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final counts = <String, int>{};
    final rawCounts = map['counts'];
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        if (entry.key is String && entry.value is num) {
          counts[entry.key as String] = (entry.value as num).toInt();
        }
      }
    }
    return PickTally(
      open: map['open'] == true,
      closesAt: _date(map['closesAt']),
      total: map['total'] is num ? (map['total'] as num).toInt() : 0,
      counts: counts,
    );
  }

  static RatingTally _rating(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final histogram = [
      for (final value in (map['histogram'] is List ? map['histogram'] : []))
        value is num ? value.toInt() : 0,
    ];
    return RatingTally(
      open: map['open'] == true,
      opensAt: _date(map['opensAt']),
      closesAt: _date(map['closesAt']),
      total: map['total'] is num ? (map['total'] as num).toInt() : 0,
      average: map['average'] is num ? (map['average'] as num).toDouble() : null,
      histogram: histogram.length == 5 ? histogram : List.filled(5, 0),
    );
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}
