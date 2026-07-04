import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';

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
