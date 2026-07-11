import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/models/race_result.dart';
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
  });

  test('home widget live payload shows lap and top three', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-03-01T12:00:00+09:00'),
      snapshot: const LiveSessionSnapshot(
        status: LiveSessionStatus.live,
        updatedAt: '2026-03-01T12:34:00Z',
        raceName: '라이브 테스트 그랑프리',
        sessionName: '레이스',
        currentLap: 12,
        totalLaps: 58,
        topThree: [
          LiveDriverPosition(
            position: 1,
            code: 'NOR',
            displayName: 'NOR',
            interval: 'LEADER',
          ),
          LiveDriverPosition(
            position: 2,
            code: 'PIA',
            displayName: 'PIA',
            interval: '+1.264',
          ),
          LiveDriverPosition(
            position: 3,
            code: 'VER',
            displayName: 'VER',
            interval: '+3.891',
          ),
        ],
      ),
    );

    expect(payload.mode, 'live');
    expect(payload.gpName, '라이브 테스트 그랑프리');
    expect(payload.liveBadge, 'LIVE');
    expect(payload.lapCurrent, 12);
    expect(payload.lapTotal, 58);
    expect(payload.topThree, ['NOR', 'PIA', 'VER']);
    expect(payload.topThreePositions, [1, 2, 3]);
    expect(payload.topThreeNames, ['랜도 노리스', '오스카 피아스트리', '막스 베르스타펜']);
    expect(payload.topThreeTimes, ['LEADER', '+1.264', '+3.891']);
    expect(payload.topThreeColors, [-30976, -30976, -14794241]);

    // 위젯 토글(라이브 ↔ 일정)용: live 모드에서도 일정 데이터를 항상 채운다.
    expect(payload.sessions, isNotEmpty);
    expect(payload.scheduleGpName, isNotEmpty);
    expect(
      payload.sessions.first.date,
      matches(RegExp(r'^\d{1,2}\.\d{1,2} [월화수목금토일]$')),
    );
  });

  test('home widget ended payload uses result badge while displayable', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-03-01T12:00:00+09:00'),
      snapshot: LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-03-01T12:34:00Z',
        raceName: '종료 테스트 그랑프리',
        currentLap: 58,
        totalLaps: 58,
        visibleUntil: DateTime.now().add(const Duration(minutes: 10)),
        topThree: const [
          LiveDriverPosition(position: 1, code: 'LEC', displayName: 'LEC'),
        ],
      ),
    );

    expect(payload.mode, 'live');
    expect(payload.liveBadge, 'RESULT');
    expect(payload.topThree, ['LEC']);
    expect(payload.topThreeNames, ['샤를 르클레르']);
    expect(payload.topThreeColors, [-1572832]);
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
    // 토글 전환용 일정 데이터도 함께 채운다
    expect(payload.sessions, isNotEmpty);
    expect(payload.scheduleGpName, isNotEmpty);
  });

  test('라이브 스냅샷이 있으면 확정 결과보다 라이브가 우선한다', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-03-01T12:00:00+09:00'),
      snapshot: const LiveSessionSnapshot(
        status: LiveSessionStatus.live,
        updatedAt: '2026-03-01T12:34:00Z',
        raceName: '라이브 우선 그랑프리',
        sessionName: '레이스',
        topThree: [
          LiveDriverPosition(position: 1, code: 'NOR', displayName: 'NOR'),
        ],
      ),
      latestResult: const LatestRaceResult(
        raceId: 'australia-2026',
        data: RaceResultData(status: 'official', entries: []),
      ),
    );

    expect(payload.mode, 'live');
  });

  test('home widget keeps live badge for qualifying between Q segments', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-07-05T00:20:00+09:00'),
      snapshot: LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-07-04T15:18:00Z',
        raceId: 'great-britain-2026',
        raceName: 'British Grand Prix',
        sessionType: 'Qualifying',
        sessionName: 'Qualifying',
        endedAt: DateTime.parse('2026-07-04T15:18:00Z'),
        topThree: const [
          LiveDriverPosition(position: 1, code: 'NOR', displayName: 'NOR'),
        ],
      ),
    );

    expect(payload.mode, 'live');
    expect(payload.liveBadge, 'LIVE');
  });

  test('home widget expired live payload falls back to default', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-03-01T12:00:00+09:00'),
      snapshot: LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-03-01T12:34:00Z',
        raceName: '만료 테스트 그랑프리',
        visibleUntil: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );

    expect(payload.mode, 'default');
    expect(payload.sessions, isNotEmpty);
  });
}
