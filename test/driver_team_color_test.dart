import 'package:flutter_test/flutter_test.dart';

import 'package:fmk_app/data/drivers.dart';
import 'package:fmk_app/data/standings.dart';
import 'package:fmk_app/data/team_colors.dart';

// 드라이버 액센트 색과 소속 팀 색이 어긋나지 않는지 지킨다.
//
// 같은 드라이버인데 화면마다 색이 다른 사고가 두 번 있었다(2026-09):
//  - 하자르가 레드불로 옮겼는데 액센트만 레이싱 불스로 남아 있었다
//  - 애스턴 마틴은 순위 화면과 라이브 계열이 서로 다른 녹색을 썼다
// 원인은 같다. 순위 계열은 teamKo 로 team_colors.dart 를, 라이브 계열은 TLA 로
// drivers.dart 의 액센트를 보는데, 시즌 라인업이 바뀌면 후자만 갱신이 빠진다.
void main() {
  // 정규 라인업에 없는 드라이버(대체 출전 등)는 소속을 단정할 수 없어 제외한다.
  // 츠노다: 2026 정규 명단 밖이지만 레드불 대체로 세 경기를 뛰어 매핑을 남겨 뒀다.
  const exemptCodes = <String>{'TSU'};

  String? teamKoOf(String driverEn) {
    for (final standing in driverStandings) {
      if (standing.driverEn == driverEn) return standing.teamKo;
    }
    // "Carlos Sainz" ↔ "Carlos Sainz Jr." 처럼 접미사만 다른 경우를 흡수한다.
    for (final standing in driverStandings) {
      if (standing.driverEn.startsWith(driverEn) ||
          driverEn.startsWith(standing.driverEn)) {
        return standing.teamKo;
      }
    }
    return null;
  }

  test('드라이버 액센트 색이 소속 팀 색과 일치한다', () {
    final mismatches = <String>[];

    for (final entry in driverNameEnByCode.entries) {
      final code = entry.key;
      if (exemptCodes.contains(code)) continue;

      final teamKo = teamKoOf(entry.value);
      // 순위 데이터에 없는 코드는 이 테스트의 대상이 아니다.
      if (teamKo == null) continue;

      final accent = liveDriverAccent(code).toARGB32();
      final teamColor = getTeamColorHex(teamKo);
      if (accent != teamColor) {
        mismatches.add(
          '$code(${entry.value}) 소속 $teamKo: '
          '팀 색 0x${teamColor.toRadixString(16)} != '
          '액센트 0x${accent.toRadixString(16)}',
        );
      }
    }

    expect(
      mismatches,
      isEmpty,
      reason:
          '드라이버 액센트와 팀 색이 갈렸다. 시즌 라인업이 바뀌면 '
          'lib/data/drivers.dart 의 액센트도 같이 고칠 것:\n'
          '${mismatches.join('\n')}',
    );
  });

  test('정규 라인업 전원이 액센트 매핑을 갖는다', () {
    final missing = <String>[];
    for (final standing in driverStandings) {
      final code = driverCodeByNameKo[standing.driverKo];
      if (code == null) {
        missing.add('${standing.driverKo}: 코드 매핑 없음');
        continue;
      }
      // 매핑에 없으면 muted 회색으로 떨어지므로 팀 색과 달라 위 테스트가 잡는다.
      if (!driverNameEnByCode.containsKey(code)) {
        missing.add('${standing.driverKo}($code): 영문 이름 매핑 없음');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('팀 색 맵이 순위 데이터의 모든 팀을 덮는다', () {
    final uncovered = <String>{};
    for (final standing in driverStandings) {
      if (!teamColorHexMap.containsKey(standing.teamKo)) {
        uncovered.add(standing.teamKo);
      }
    }
    expect(
      uncovered,
      isEmpty,
      reason: '기본 회색으로 떨어지는 팀이 있다: ${uncovered.join(", ")}',
    );
  });
}
