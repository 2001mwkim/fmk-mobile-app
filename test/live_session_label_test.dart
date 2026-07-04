import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fmk_app/data/races.dart';
import 'package:fmk_app/data/team_colors.dart';
import 'package:fmk_app/models/live_session.dart';

void main() {
  group('liveSessionLabelKo', () {
    test('maps English session names to Korean', () {
      expect(liveSessionLabelKo('Race', 'Race'), '레이스');
      expect(liveSessionLabelKo('Qualifying', null), '퀄리파잉');
      expect(liveSessionLabelKo('Sprint', null), '스프린트');
      expect(liveSessionLabelKo('Sprint Qualifying', null), '스프린트 퀄리파잉');
      expect(liveSessionLabelKo('Practice 1', null), '프리 프랙티스 1');
      expect(liveSessionLabelKo('Practice 3', null), '프리 프랙티스 3');
      expect(liveSessionLabelKo('FP2', null), '프리 프랙티스 2');
    });

    test('keeps already-Korean values and falls back safely', () {
      expect(liveSessionLabelKo('레이스', null), '레이스');
      expect(liveSessionLabelKo(null, null), '세션');
      expect(liveSessionLabelKo('  ', ''), '세션');
    });
  });

  group('resolveLiveRace', () {
    test('resolves suffixed id from a short live raceId', () {
      final race = resolveLiveRace('spain', 'Spanish Grand Prix');
      expect(race?.nameKo, '스페인 그랑프리');
    });

    test('resolves by English race name when id misses', () {
      final race = resolveLiveRace('unknown-id', 'Australian Grand Prix');
      expect(race?.nameKo, '호주 그랑프리');
    });

    test('returns null when nothing matches', () {
      expect(resolveLiveRace('nope', 'Not A Real GP'), isNull);
    });
  });

  group('liveEndedResultVisibleUntil / isLiveSnapshotDisplayable', () {
    // 영국 GP(스프린트 주말): 스프린트 종료(2026-07-04 20:30 KST) 후 다음 세션은
    // 퀄리파잉(2026-07-05 00:00 KST = 07-04 15:00Z).
    final sprintEndedAt = DateTime.parse('2026-07-04T11:30:11Z');

    test('keeps result until 30min before the next session', () {
      final until = liveEndedResultVisibleUntil(
        raceId: 'great-britain-2026',
        raceName: 'British Grand Prix',
        endedAt: sprintEndedAt,
      );
      // 퀄리 시작 07-04 15:00Z 의 30분 전 = 14:30Z.
      expect(until, DateTime.parse('2026-07-04T14:30:00Z'));
    });

    test('final race stays for one hour after it ends', () {
      // 레이스 시작 2026-07-05 23:00 KST(=14:00Z) + 180분 => 17:00Z 종료.
      final raceEndedAt = DateTime.parse('2026-07-05T17:00:00Z');
      final until = liveEndedResultVisibleUntil(
        raceId: 'great-britain-2026',
        endedAt: raceEndedAt,
      );
      expect(until, raceEndedAt.add(const Duration(hours: 1)));
    });

    test(
      'returns null when race or endedAt is missing (caller falls back)',
      () {
        expect(
          liveEndedResultVisibleUntil(raceId: 'nope', endedAt: sprintEndedAt),
          isNull,
        );
        expect(
          liveEndedResultVisibleUntil(
            raceId: 'great-britain-2026',
            endedAt: null,
          ),
          isNull,
        );
      },
    );

    test('displayable until the next session window closes', () {
      final snapshot = LiveSessionSnapshot(
        status: LiveSessionStatus.ended,
        updatedAt: '',
        raceId: 'great-britain-2026',
        raceName: 'British Grand Prix',
        endedAt: sprintEndedAt,
      );

      // 종료 30분 뒤(=기존 visibleUntil 만료)여도 다음 세션 30분 전까지는 노출.
      expect(
        isLiveSnapshotDisplayable(
          snapshot,
          DateTime.parse('2026-07-04T13:00:00Z'),
        ),
        isTrue,
      );
      // 퀄리 30분 전 이후에는 숨김.
      expect(
        isLiveSnapshotDisplayable(
          snapshot,
          DateTime.parse('2026-07-04T14:45:00Z'),
        ),
        isFalse,
      );
    });

    test(
      'ended qualifying segment is treated as live during session window',
      () {
        final snapshot = LiveSessionSnapshot(
          status: LiveSessionStatus.ended,
          updatedAt: '',
          raceId: 'great-britain-2026',
          raceName: 'British Grand Prix',
          sessionType: 'Qualifying',
          sessionName: 'Qualifying',
          endedAt: DateTime.parse('2026-07-04T15:18:00Z'),
        );

        final duringQ2 = DateTime.parse('2026-07-04T15:20:00Z');
        expect(isLiveSnapshotSessionActive(snapshot, duringQ2), isTrue);
        expect(isLiveSnapshotDisplayable(snapshot, duringQ2), isTrue);

        final afterQualifyingWindow = DateTime.parse('2026-07-04T16:01:00Z');
        expect(
          isLiveSnapshotSessionActive(snapshot, afterQualifyingWindow),
          isFalse,
        );
        expect(
          isLiveSnapshotDisplayable(snapshot, afterQualifyingWindow),
          isTrue,
        );
      },
    );

    test(
      'ended snapshot without endedAt falls back to scheduled session end',
      () {
        // collector 가 퀄리 종료 후 재시작된 경우: status=ended, endedAt 없음.
        final snapshot = LiveSessionSnapshot(
          status: LiveSessionStatus.ended,
          updatedAt: '',
          raceId: 'great-britain-2026',
          raceName: 'British Grand Prix',
          sessionType: 'Qualifying',
          sessionName: 'Qualifying',
        );

        // 스케줄상 퀄리 종료(07-04 16:00Z) 뒤, 레이스(07-05 14:00Z) 30분 전까지 노출.
        expect(
          isLiveSnapshotDisplayable(
            snapshot,
            DateTime.parse('2026-07-04T17:00:00Z'),
          ),
          isTrue,
        );
        // 레이스 시작 30분 전 이후에는 숨김.
        expect(
          isLiveSnapshotDisplayable(
            snapshot,
            DateTime.parse('2026-07-05T13:45:00Z'),
          ),
          isFalse,
        );

        // 레이스/세션 매칭이 안 되면 기존 규칙(visibleUntil 없음 → 숨김) 유지.
        final unresolvable = LiveSessionSnapshot(
          status: LiveSessionStatus.ended,
          updatedAt: '',
          raceId: 'nope',
          raceName: 'Not A Real GP',
          sessionType: 'Qualifying',
        );
        expect(
          isLiveSnapshotDisplayable(
            unresolvable,
            DateTime.parse('2026-07-04T17:00:00Z'),
          ),
          isFalse,
        );
      },
    );
  });

  test('Audi drivers use the standings dark-grey accent', () {
    final audiColor = getTeamColor('아우디');
    expect(liveDriverAccent('HUL'), audiColor);
    expect(liveDriverAccent('BOR'), audiColor);
    // 옛 킥 자우버 연두색이 아니어야 한다.
    expect(liveDriverAccent('HUL'), isNot(const Color(0xFF52E252)));
  });
}
