import 'team_colors.dart';

/// 2026 시즌 팀(컨스트럭터) 기준 매핑 모음 — 순위 데이터의 teamKo 가 키.
///
/// MY TEAM 설정·위젯이 쓴다. 팀 컬러는 team_colors.dart 가 단일 출처이고,
/// 여기서는 표기(영문 이름·약어)와 노출 순서만 정한다. 라인업/팀명 변경 시
/// drivers.dart 와 함께 이 파일만 갱신하면 된다.

/// 표시 순서(선택기 기본 정렬 — 순위 데이터가 있으면 순위순으로 덮어쓴다).
const List<String> teamKoList = [
  '맥라렌',
  '페라리',
  '메르세데스',
  '레드불 레이싱',
  '윌리엄스',
  '알핀',
  '레이싱 불스',
  '하스',
  '애스턴 마틴',
  '캐딜락',
  '아우디',
];

/// teamKo → 영문 팀명(위젯 MY TEAM 표기).
const Map<String, String> teamNameEnByKo = {
  '맥라렌': 'McLaren',
  '페라리': 'Ferrari',
  '메르세데스': 'Mercedes',
  '레드불 레이싱': 'Red Bull Racing',
  '윌리엄스': 'Williams',
  '알핀': 'Alpine',
  '레이싱 불스': 'Racing Bulls',
  '하스': 'Haas',
  '애스턴 마틴': 'Aston Martin',
  '캐딜락': 'Cadillac',
  '아우디': 'Audi',
  '킥 자우버': 'Kick Sauber',
};

/// teamKo → 3글자 약어(위젯의 큰 타이포용 — 드라이버 TLA 와 같은 무게감).
const Map<String, String> teamCodeByKo = {
  '맥라렌': 'MCL',
  '페라리': 'FER',
  '메르세데스': 'MER',
  '레드불 레이싱': 'RBR',
  '윌리엄스': 'WIL',
  '알핀': 'ALP',
  '레이싱 불스': 'RB',
  '하스': 'HAA',
  '애스턴 마틴': 'AMR',
  '캐딜락': 'CAD',
  '아우디': 'AUD',
  '킥 자우버': 'SAU',
};

/// 팀 영문명. 매핑에 없으면 [fallback](서버 teamEn 등).
String teamNameEn(String teamKo, String fallback) =>
    teamNameEnByKo[teamKo] ?? fallback;

/// 팀 약어. 매핑에 없으면 영문/한글명의 앞 3글자를 대문자로.
String teamCode(String teamKo, {String fallbackEn = ''}) {
  final known = teamCodeByKo[teamKo];
  if (known != null) return known;
  final source = fallbackEn.isNotEmpty ? fallbackEn : teamKo;
  final compact = source.replaceAll(RegExp(r'\s+'), '');
  return compact.length <= 3
      ? compact.toUpperCase()
      : compact.substring(0, 3).toUpperCase();
}

/// 팀 컬러(ARGB int) — team_colors.dart 위임(단일 출처 유지).
int teamColorArgb(String teamKo) => getTeamColorHex(teamKo);
