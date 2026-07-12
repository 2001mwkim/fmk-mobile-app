import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/live_session_service.dart';

void main() {
  test('parseLiveJson maps collector live.json into a snapshot', () {
    const body = '''
{
  "snapshot": {
    "status": "live",
    "mode": "live-candidate",
    "raceId": "spain",
    "raceName": "스페인 그랑프리",
    "sessionType": "Race",
    "sessionName": "레이스",
    "currentLap": 42,
    "totalLaps": 66,
    "updatedAt": "2026-06-30T13:34:56.000Z",
    "topThree": [
      {"position": 1, "racingNumber": "4", "code": "NOR", "displayName": "랜도 노리스", "source": "top-three"},
      {"position": 2, "racingNumber": "81", "code": "PIA", "displayName": "오스카 피아스트리", "interval": "+2.341", "source": "top-three"},
      {"position": 3, "racingNumber": "16", "code": "LEC", "displayName": "샤를 르클레르", "interval": "+5.118", "source": "top-three"}
    ],
    "classification": [
      {"position": 1, "racingNumber": "4", "code": "NOR", "displayName": "랜도 노리스", "gapToLeader": null, "source": "timing-data"},
      {"position": 2, "racingNumber": "81", "code": "PIA", "displayName": "오스카 피아스트리", "interval": "+2.341", "lapTime": "1:28.626", "displayTime": "1:28.626", "lastLapTime": "1:28.801", "bestLapTime": "1:28.626", "personalBestLapTime": "1:28.626", "source": "timing-data"}
    ]
  },
  "collector": {"feedUpdates": 10}
}
''';

    final snapshot = parseLiveJson(body);
    expect(snapshot, isNotNull);
    expect(snapshot!.status, LiveSessionStatus.live);
    expect(snapshot.raceId, 'spain');
    expect(snapshot.currentLap, 42);
    expect(snapshot.totalLaps, 66);
    expect(snapshot.isRaceOrSprint, isTrue);
    expect(snapshot.topThree.length, 3);
    expect(snapshot.topThree.first.code, 'NOR');
    expect(snapshot.classification.length, 2);
    // interval 우선(race) 갭 규칙
    expect(snapshot.topThree[1].gap(raceLike: true), '+2.341');
    expect(snapshot.classification[1].displayTime, '1:28.626');
    expect(snapshot.classification[1].time(raceLike: false), '1:28.626');

    // 잘못된 본문은 null (앱 크래시 방지)
    expect(parseLiveJson('not json'), isNull);
    expect(parseLiveJson('{"snapshot": 123}'), isNull);
  });

  test('parseLiveJson caps oversized classification lists', () {
    // 오염/위조된 서버가 초대형 배열을 내려보내는 상황 방어(리스트 상한 40).
    final rows = List.generate(
      200,
      (i) =>
          '{"position": ${i + 1}, "racingNumber": "$i", '
          '"code": "D$i", "displayName": "Driver $i"}',
    ).join(',');
    final snapshot = parseLiveJson(
      '{"snapshot": {"status": "live", "updatedAt": "", '
      '"classification": [$rows]}}',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.classification.length, 40);
  });

  test('parseLiveJson maps live center details', () {
    const body = '''
{"snapshot":{"status":"live","updatedAt":"2026-07-12T01:00:00Z",
"trackStatus":"6","remainingTime":"12:34",
"weather":{"airTemp":"24.5","trackTemp":38.2,"humidity":61,"rainfall":"false","windSpeed":2.8},
"classification":[{"position":1,"code":"NOR","displayName":"Lando Norris","compound":"MEDIUM","tyreAge":12,"pitStops":1,"sector1":"28.101","sector2":"35.202","sector3":"24.303"}],
"raceControlMessages":[{"Utc":"2026-07-12T01:01:00Z","Category":"Flag","Flag":"YELLOW","Message":"YELLOW FLAG IN TURN 3"}]}}
''';

    final snapshot = parseLiveJson(body)!;
    expect(snapshot.trackStatus, '6');
    expect(snapshot.remainingTime, '12:34');
    expect(snapshot.weather!.airTemperature, 24.5);
    expect(snapshot.weather!.rainfall, isFalse);
    expect(snapshot.classification.single.compound, 'MEDIUM');
    expect(snapshot.classification.single.tyreAge, 12);
    expect(snapshot.classification.single.sector2, '35.202');
    expect(snapshot.raceControlMessages.single.flag, 'YELLOW');
  });

  test('ended race is not treated live within its scheduled window', () {
    // 레이스가 스케줄상 종료 창(시작+3시간)보다 일찍 끝난 상황.
    final snapshot = LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '2026-07-05T15:35:00.000Z',
      raceId: 'great-britain-2026',
      raceName: '영국 그랑프리',
      sessionType: 'Race',
      sessionName: 'Race',
      endedAt: DateTime.parse('2026-07-05T15:31:00Z'),
    );
    final duringWindow = DateTime.parse('2026-07-06T00:40:00+09:00');

    // 세그먼트가 없는 레이스는 ended = 실제 종료 → LIVE로 되돌리지 않는다.
    expect(isLiveSnapshotSessionActive(snapshot, duringWindow), isFalse);
    // 다만 최종 결과로는 계속 노출(마지막 세션 종료 +1시간 규칙).
    expect(isLiveSnapshotDisplayable(snapshot, duringWindow), isTrue);
  });

  test('ended within 30min is displayable, expired is hidden', () {
    final now = DateTime.now();
    LiveSessionSnapshot ended(DateTime visibleUntil) => LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: '',
      visibleUntil: visibleUntil,
    );

    expect(ended(now.add(const Duration(minutes: 25))).isDisplayable, isTrue);
    expect(
      ended(now.subtract(const Duration(minutes: 10))).isDisplayable,
      isFalse,
    );
    // visibleUntil 이 없으면 미표시
    expect(
      const LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '',
      ).isDisplayable,
      isFalse,
    );
  });

  test('updatedAtLabel formats KST (UTC+9)', () {
    const live = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '2026-06-30T04:34:00.000Z',
    );
    expect(live.updatedAtLabel, '업데이트 13:34 KST');

    const empty = LiveSessionSnapshot(
      status: LiveSessionStatus.live,
      updatedAt: '',
    );
    expect(empty.updatedAtLabel, isNull);
  });

  test('liveCountryFlag maps raceId to a flag, safe on miss', () {
    expect(liveCountryFlag('japan-2026'), '🇯🇵');
    expect(liveCountryFlag('does-not-exist'), isNull);
    expect(liveCountryFlag(null), isNull);
  });
}
