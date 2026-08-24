import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/standing_insights.dart';
import 'package:fmk_app/models/race_result.dart';

void main() {
  RaceResultEntry result({
    required int position,
    required String driver,
    required String team,
    required num points,
  }) => RaceResultEntry(
    position: position,
    positionLabel: '$position',
    driverKo: driver,
    driverEn: driver,
    teamKo: team,
    teamEn: team,
    points: points,
  );

  test('서버에 새 라운드가 추가되면 최근 결과와 순위 흐름도 마지막 라운드까지 간다', () {
    final results = <String, List<RaceResultEntry>>{
      'barcelona-catalunya-2026': [
        result(position: 2, driver: '테스트 드라이버', team: '테스트 팀', points: 18),
        result(position: 1, driver: '라이벌', team: '라이벌 팀', points: 25),
      ],
      'austria-2026': [
        result(position: 1, driver: '테스트 드라이버', team: '테스트 팀', points: 26),
        result(position: 2, driver: '라이벌', team: '라이벌 팀', points: 18),
      ],
    };

    final recent = recentDriverResults('테스트 드라이버', resultsByRaceId: results);
    final trend = driverStandingTrend('테스트 드라이버', resultsByRaceId: results);

    expect(recent.first.race.round, 8);
    expect(trend.last.round, 8);
    expect(trend.last.position, 1);
  });
}
