import 'dart:convert';

/// collector `/gap-history.json` 응답 — 레이스/스프린트의 랩별 선두와의 간격.
///
/// 계약(자매 저장소 `lib/live/gapHistory.ts`): 드라이버가 랩을 마칠 때의
/// GapToLeader(초). 선두는 0, 랩다운·피트·리타이어는 null. `?delay=N` 이면
/// 서버가 N초 전까지 기록된 값만 내려준다(영상 지연 스포일러 방지).
class GapHistory {
  const GapHistory({
    required this.available,
    required this.drivers,
    required this.laps,
    this.raceId,
    this.sessionType,
  });

  static const GapHistory empty = GapHistory(
    available: false,
    drivers: [],
    laps: [],
  );

  final bool available;
  final String? raceId;
  final String? sessionType;

  /// TLA, 현재 순위 순서.
  final List<String> drivers;

  /// 오름차순 랩.
  final List<GapLap> laps;

  bool get hasData => available && laps.isNotEmpty;

  /// [code] 의 (랩, 간격) 점들. 값이 없거나 null 인 랩은 빠진다 — 선이 끊긴다.
  List<(int, double)> seriesFor(String code) => [
    for (final lap in laps)
      if (lap.gaps[code] case final double gap) (lap.lap, gap),
  ];

  static GapHistory? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final drivers = [
        for (final code in (decoded['drivers'] as List? ?? const []))
          if (code is String && code.isNotEmpty) code,
      ];
      final laps = <GapLap>[];
      for (final raw in (decoded['laps'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final lap = raw['lap'];
        final gaps = raw['gaps'];
        if (lap is! num || gaps is! Map) continue;
        laps.add(
          GapLap(
            lap: lap.toInt(),
            gaps: {
              for (final entry in gaps.entries)
                if (entry.key is String)
                  entry.key as String: entry.value is num
                      ? (entry.value as num).toDouble()
                      : null,
            },
          ),
        );
      }
      laps.sort((a, b) => a.lap.compareTo(b.lap));
      return GapHistory(
        available: decoded['available'] == true,
        raceId: decoded['raceId'] is String ? decoded['raceId'] as String : null,
        sessionType: decoded['sessionType'] is String
            ? decoded['sessionType'] as String
            : null,
        drivers: drivers,
        laps: laps,
      );
    } catch (_) {
      return null;
    }
  }
}

class GapLap {
  const GapLap({required this.lap, required this.gaps});

  final int lap;

  /// TLA → 선두와의 간격(초). null 은 랩다운·피트 등 비교 불가.
  final Map<String, double?> gaps;
}
