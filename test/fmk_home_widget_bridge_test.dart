import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/models/race_result.dart';
import 'package:fmk_app/models/standing.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';
import 'package:fmk_app/services/race_results_repository.dart';

void main() {
  test('home widget default payload shows next grand prix sessions', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-03-01T12:00:00+09:00'),
    );

    expect(payload.mode, 'default');
    expect(payload.gpName, isNotEmpty);
    expect(payload.sessions, isNotEmpty);
    expect(payload.sessions.length, lessThanOrEqualTo(5));
    expect(payload.sessions.first.name, isNotEmpty);
    expect(
      payload.sessions.first.date,
      matches(RegExp(r'^\d{1,2}\.\d{1,2} [월화수목금토일]$')),
    );
    expect(payload.sessions.first.time, matches(RegExp(r'^\d{2}:\d{2}$')));
    // 주말 시작 전에는 첫 세션이 '다음 세션' 하이라이트.
    expect(payload.sessionHighlightIndex, 1);
  });

  test('세션이 지나면 하이라이트가 다음 세션으로 넘어간다', () {
    final race = getNextRace(DateTime.parse('2026-03-01T12:00:00+09:00'));
    final firstStart = getSessionDate(race, race.sessions.first);

    final payload = buildFmkHomeWidgetPayload(
      now: firstStart.add(const Duration(minutes: 1)),
    );

    expect(payload.sessionHighlightIndex, 2);
  });

  test('라이브가 없으면 확정 결과로 result 모드 페이로드를 만든다', () {
    RaceResultEntry entry(int position, String driverKo, String teamKo) =>
        RaceResultEntry(
          position: position,
          positionLabel: '$position',
          driverKo: driverKo,
          driverEn: 'Driver $position',
          teamKo: teamKo,
          teamEn: 'Team',
          points: 26 - position,
          time: position == 1 ? '1:27:11.335' : null,
          gap: position == 1 ? null : '+$position.0',
        );

    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-07-10T12:00:00+09:00'),
      latestResult: LatestRaceResult(
        raceId: 'great-britain-2026',
        data: RaceResultData(
          status: 'official',
          entries: [
            entry(1, '샤를 르클레르', '페라리'),
            entry(2, '조지 러셀', '메르세데스'),
            entry(3, '루이스 해밀턴', '페라리'),
            entry(4, '무시될 드라이버', '팀'),
          ],
        ),
      ),
    );

    expect(payload.mode, 'result');
    expect(payload.isResult, isTrue);
    expect(payload.gpName, '영국 그랑프리'); // raceId → 앱 레이스명
    expect(payload.liveBadge, 'RESULT'); // 위젯 토글 우측 라벨 = '결과'
    expect(payload.lapTotal, 0); // 랩 영역 숨김
    expect(payload.topThreeNames, ['샤를 르클레르', '조지 러셀', '루이스 해밀턴']);
    expect(payload.topThreePositions, [1, 2, 3]);
    // 1위는 총 시간, 이후는 갭(결과 패널과 동일 규칙)
    expect(payload.topThreeTimes, ['1:27:11.335', '+2.0', '+3.0']);
    expect(payload.topThreeColors.length, 3);
    expect(payload.resultSessionLabel, '레이스'); // iOS 라이브·결과 위젯 배지
    // 토글 전환용 일정 데이터도 함께 채운다
    expect(payload.sessions, isNotEmpty);
    expect(payload.scheduleGpName, isNotEmpty);
  });

  test('퀄리/연습 결과 모드는 행별 랩타임을 쓰고 갭으로 폴백하지 않는다', () {
    RaceResultEntry entry(int position, {String? time, String? gap}) =>
        RaceResultEntry(
          position: position,
          positionLabel: '$position',
          driverKo: '드라이버 $position',
          driverEn: 'Driver $position',
          teamKo: '페라리',
          teamEn: 'Ferrari',
          points: 0,
          time: time,
          gap: gap,
        );

    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-07-10T12:00:00+09:00'),
      latestResult: LatestRaceResult(
        raceId: 'great-britain-2026',
        sessionType: 'QUALIFYING',
        data: RaceResultData(
          status: 'official',
          entries: [
            entry(1, time: '1:25.001'),
            entry(2, time: '1:25.120', gap: '+0.119'),
            entry(3, gap: '+0.300'), // 랩타임 없음 → '—'(갭 폴백 금지)
          ],
        ),
      ),
    );

    expect(payload.mode, 'result');
    expect(payload.resultSessionLabel, '퀄리파잉');
    expect(payload.topThreeTimes, ['1:25.001', '1:25.120', '—']);
  });

  test('순위 위젯 행: ▲▼— 라벨/색과 포인트 표기를 만든다', () {
    final rows = buildFmkStandingsWidgetRows(
      driverStandings: const [
        DriverStanding(
          position: 1,
          driverKo: '드라이버A',
          driverEn: 'A',
          teamKo: '메르세데스',
          teamEn: 'Mercedes',
          points: 179,
          positionChange: 0,
        ),
        DriverStanding(
          position: 2,
          driverKo: '드라이버B',
          driverEn: 'B',
          teamKo: '페라리',
          teamEn: 'Ferrari',
          points: 154.5,
          positionChange: 2,
        ),
        DriverStanding(
          position: 3,
          driverKo: '드라이버C',
          driverEn: 'C',
          teamKo: '맥라렌',
          teamEn: 'McLaren',
          points: 120,
          positionChange: -1,
        ),
        DriverStanding(
          position: 4,
          driverKo: '드라이버D',
          driverEn: 'D',
          teamKo: '윌리엄스',
          teamEn: 'Williams',
          points: 90,
        ),
        DriverStanding(
          position: 5,
          driverKo: '드라이버E',
          driverEn: 'E',
          teamKo: '하스',
          teamEn: 'Haas',
          points: 80,
        ),
        DriverStanding(
          position: 6,
          driverKo: '잘린 드라이버',
          driverEn: 'F',
          teamKo: '아우디',
          teamEn: 'Audi',
          points: 70,
        ),
      ],
    );

    expect(rows.length, 5); // Top 5 로 자른다
    expect(rows.first.name, '드라이버A');
    expect(rows.first.points, '179');
    expect(rows.first.changeLabel, '—');
    expect(rows[1].points, '154.5');
    expect(rows[1].changeLabel, '▲2');
    expect(rows[1].changeColor, 0xFF4ADE80); // green
    expect(rows[2].changeLabel, '▼1');
    expect(rows[2].changeColor, 0xFFF87171); // redSoft
    expect(rows[3].changeLabel, ''); // null(정적 폴백)이면 미표시
  });

  test('순위 위젯 행: 컨스트럭터도 같은 규칙으로 변환한다', () {
    final rows = buildFmkStandingsWidgetRows(
      constructorStandings: const [
        ConstructorStanding(
          position: 1,
          teamKo: '메르세데스',
          teamEn: 'Mercedes',
          points: 333,
          positionChange: 0,
        ),
      ],
    );

    expect(rows.single.name, '메르세데스');
    expect(rows.single.points, '333');
    expect(rows.single.changeLabel, '—');
  });

  test('위젯 딥링크 URI → 하단 탭 인덱스 매핑', () {
    expect(fmkWidgetTabIndexForUri(Uri.parse('fmkwidget://home')), 0);
    expect(fmkWidgetTabIndexForUri(Uri.parse('fmkwidget://standings')), 2);
    expect(fmkWidgetTabIndexForUri(Uri.parse('fmkwidget://live')), 3);
    // 모르는 대상/스킴/null 은 무시(현재 탭 유지).
    expect(fmkWidgetTabIndexForUri(Uri.parse('fmkwidget://unknown')), isNull);
    expect(fmkWidgetTabIndexForUri(Uri.parse('https://live')), isNull);
    expect(fmkWidgetTabIndexForUri(null), isNull);
  });

}
