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

  test('누적 포인트 동률은 이름순이 아니라 최고 성적 카운트백으로 정렬한다', () {
    final results = <String, List<RaceResultEntry>>{
      'australia-2026': [
        result(position: 1, driver: '제트', team: '제트 팀', points: 10),
        result(position: 2, driver: '알파', team: '알파 팀', points: 15),
      ],
      'china-2026': [
        result(position: 5, driver: '제트', team: '제트 팀', points: 10),
        result(position: 3, driver: '알파', team: '알파 팀', points: 5),
      ],
    };

    final winner = driverStandingTrend('제트', resultsByRaceId: results);
    final runnerUp = driverStandingTrend('알파', resultsByRaceId: results);

    expect(winner.last.position, 1); // 20점 동률, 제트가 우승 1회
    expect(runnerUp.last.position, 2);
  });
}
