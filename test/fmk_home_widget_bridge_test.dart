import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/models/live_session.dart';
import 'package:fmk_app/services/fmk_home_widget_bridge.dart';

void main() {
  test('home widget payload shows live lap and top three first', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-06-30T12:00:00+09:00'),
      snapshot: const LiveSessionSnapshot(
        status: LiveSessionStatus.live,
        updatedAt: '2026-06-30T12:34:00Z',
        raceName: '테스트 그랑프리',
        sessionName: '레이스',
        currentLap: 12,
        totalLaps: 58,
        topThree: [
          LiveDriverPosition(position: 1, code: 'NOR', displayName: 'NOR'),
          LiveDriverPosition(position: 2, code: 'PIA', displayName: 'PIA'),
          LiveDriverPosition(position: 3, code: 'VER', displayName: 'VER'),
        ],
      ),
    );

    expect(payload.badge, 'LIVE');
    expect(payload.title, '테스트 그랑프리');
    expect(payload.primary, 'Lap 12 / 58');
    expect(payload.secondary, 'Top 3 NOR · PIA · VER');
    expect(payload.updated, '업데이트 21:34 KST');
  });

  test('home widget payload shows recently ended snapshot as final result', () {
    final payload = buildFmkHomeWidgetPayload(
      now: DateTime.parse('2026-06-30T12:00:00+09:00'),
      snapshot: LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '2026-06-30T12:40:00Z',
        raceName: '테스트 그랑프리',
        sessionName: '레이스',
        visibleUntil: DateTime.now().add(const Duration(minutes: 10)),
        topThree: const [
          LiveDriverPosition(position: 1, code: 'LEC', displayName: 'LEC'),
          LiveDriverPosition(position: 2, code: 'HAM', displayName: 'HAM'),
          LiveDriverPosition(position: 3, code: 'RUS', displayName: 'RUS'),
        ],
      ),
    );

    expect(payload.badge, '최종 결과');
    expect(payload.primary, 'Top 3 LEC · HAM · RUS');
    expect(payload.updated, '업데이트 21:40 KST');
  });

  test(
    'home widget payload falls back to next session when snapshot expired',
    () {
      final payload = buildFmkHomeWidgetPayload(
        now: DateTime.parse('2026-07-01T12:00:00+09:00'),
        snapshot: LiveSessionSnapshot(
          status: LiveSessionStatus.ended,
          updatedAt: '2026-06-30T12:40:00Z',
          raceName: '테스트 그랑프리',
          visibleUntil: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );

      expect(payload.badge, isNot('최종 결과'));
      expect(payload.title, isNotEmpty);
      expect(payload.primary, isNotEmpty);
      expect(payload.updated, '업데이트 12:00 KST');
    },
  );
}
