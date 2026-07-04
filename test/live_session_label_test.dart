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

  test('Audi drivers use the standings dark-grey accent', () {
    final audiColor = getTeamColor('아우디');
    expect(liveDriverAccent('HUL'), audiColor);
    expect(liveDriverAccent('BOR'), audiColor);
    // 옛 킥 자우버 연두색이 아니어야 한다.
    expect(liveDriverAccent('HUL'), isNot(const Color(0xFF52E252)));
  });
}
