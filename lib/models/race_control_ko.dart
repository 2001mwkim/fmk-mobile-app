import '../data/drivers.dart';

/// 레이스 컨트롤 메시지 한국어 번역 (규칙 기반).
///
/// FIA 레이스 컨트롤 메시지는 정해진 문형("[위치] INCIDENT INVOLVING CAR n (TLA)
/// [처리 상태] - [사유]" 등)으로만 나와서 AI 번역 없이 규칙으로 옮길 수 있다.
/// 규칙은 2025~2026 전 세션 아카이브 14,785건을 문형별로 묶어 빈도순으로
/// 뽑았다(2026-10). 모르는 문형이나 모르는 사유가 하나라도 섞이면 **null 을
/// 돌려주고 화면은 원문을 그대로 보여 준다** — 반쯤 번역된 문장보다 원문이 낫다.
///
/// 메시지 속 시각(`TIMED AT 16:07:48`, `RESUME AT 14:30`)은 **서킷 현지 시각**이라
/// KST 로 바꿀 근거(서킷 UTC 오프셋)가 메시지에 없다. 블루 플래그 시각은
/// 카드에 수신 시각이 따로 있으니 버리고, 재개·시작 예정 시각은 "현지"로 표기한다.
String? translateRaceControlMessage(String raw) {
  final text = raw
      .toUpperCase()
      .replaceAll(RegExp(r'[–—]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      // "NOTED -YELLOW FLAG ..." 처럼 대시 뒤 공백이 빠진 오타가 가끔 온다.
      .replaceAll(RegExp(r' -(?=[A-Z])'), ' - ')
      .trim();
  if (text.isEmpty) return null;

  // 앞서 낸 메시지를 고치거나 갱신해 다시 보낼 때 "CORRECTION:"/"UPDATE:" 가
  // 붙는다(드물게 "CORRECTION - ").
  final amend = RegExp(r'^(CORRECTION|UPDATE)(?::+| -) ').firstMatch(text);
  if (amend != null) {
    final rest = translateRaceControlMessage(text.substring(amend.end));
    if (rest == null) return null;
    return '${amend[1] == 'UPDATE' ? '[갱신]' : '[정정]'} $rest';
  }

  // 차량 표기("CAR 44 (HAM)", "CARS 87 (BEA), 6 (HAD) AND 63 (RUS)")를 먼저
  // 한글 라벨로 뽑아 두고 문장에서는 § 하나로 치환한다 — 아래 문형 정규식이
  // 차량 수와 무관해진다.
  String? cars;
  final carMatch = _carsPattern.firstMatch(text);
  var body = text;
  if (carMatch != null) {
    cars = _carLabels(carMatch.group(1)!);
    body = text.replaceRange(carMatch.start, carMatch.end, '§');
  }

  for (final rule in _rules) {
    final match = rule.pattern.firstMatch(body);
    if (match == null) continue;
    return rule.build(match, cars ?? '');
  }
  return null;
}

final _carsPattern = RegExp(
  r'\bCARS? (\d+(?: \([A-Z]{2,3}\))?(?:(?:, | AND |,)\d+(?: \([A-Z]{2,3}\))?)*)',
);
final _singleCar = RegExp(r'(\d+)(?: \(([A-Z]{2,3})\))?');

String _carLabels(String group) {
  return _singleCar
      .allMatches(group)
      .map((m) {
        final number = m.group(1)!;
        final code = m.group(2);
        if (code == null) return '$number번';
        final name = driverNameKoByCode[code];
        // 성만 쓴다(목록이 길어지는 다중 차량 메시지 대비). 미등록 드라이버는 TLA.
        final short = name == null ? code : name.split(' ').last;
        return '$short($number)';
      })
      .join(', ');
}

class _Rule {
  const _Rule(this.pattern, this.build);
  final RegExp pattern;
  final String? Function(RegExpMatch m, String cars) build;
}

RegExp _re(String source) => RegExp('^$source\$');

// 사건·페널티 문형 끝의 `(?: \(14:05\)| 14:05:33)?` 는 메시지 꼬리에 붙는
// 현지 시각 표기다 — 번역문에선 버린다.

final List<_Rule> _rules = [
  // ── 깃발 ────────────────────────────────────────────────────────────
  _Rule(_re(r'CLEAR IN TRACK SECTOR (\d+)'), (m, _) => '섹터 ${m[1]} 클리어'),
  _Rule(
    _re(r'DOUBLE YELLOW IN TRACK SECTOR (\d+)'),
    (m, _) => '섹터 ${m[1]} 더블 옐로 플래그',
  ),
  _Rule(
    _re(r'YELLOW IN TRACK SECTOR (\d+)'),
    (m, _) => '섹터 ${m[1]} 옐로 플래그',
  ),
  _Rule(_re(r'YELLOW IN PIT LANE'), (m, _) => '피트레인 옐로 플래그'),
  _Rule(
    _re(r'WAVED BLUE FLAG FOR §(?: TIMED AT [\d:]+)?'),
    (m, cars) => '$cars 블루 플래그',
  ),
  _Rule(
    _re(r'BLACK AND WHITE FLAG FOR §(?: - (.+))?'),
    (m, cars) => m[1] == null
        ? '$cars 흑백기(경고)'
        : _withReason('$cars 흑백기(경고)', m[1]!),
  ),
  _Rule(
    _re(r'BLACK AND ORANGE FLAG FOR §'),
    (m, cars) => '$cars 오렌지 볼 플래그(기계 결함 — 피트인 지시)',
  ),
  _Rule(_re(r'CHEQUERED FLAG'), (m, _) => '체커드 플래그'),
  _Rule(_re(r'TRACK CLEAR'), (m, _) => '트랙 클리어'),
  _Rule(_re(r'RED FLAG'), (m, _) => '레드 플래그'),
  _Rule(_re(r'RED FLAG - (?:RACE|SESSION) SUSPENDED'), (m, _) => '레드 플래그 — 중단'),
  _Rule(
    _re(r'FIRST CAR TO TAKE THE FLAG - §'),
    (m, cars) => '체커드 플래그 첫 수신 예정: $cars',
  ),

  // ── 랩타임 삭제/복원 ────────────────────────────────────────────────
  _Rule(
    _re(
      r'§ (?:TIME ([\d:.]+)|LAP) DELETED - (TRACK LIMITS|DOUBLE YELLOW|YELLOW FLAG|RED FLAG) AT TURN (\d+)'
      r'(?: LAP (\d+))?(?: \d{1,2}:\d{2}:\d{2})?(?: \((NEXT LAP PIT|NEXT LAP|PIT)\))?',
    ),
    (m, cars) {
      final what = m[1] == null ? '랩 기록' : '랩타임 ${m[1]}';
      final reason = _deletionReasons[m[2]]!;
      final where = [
        '${m[3]}번 코너',
        if (m[4] != null) '${m[4]}랩',
      ].join(' · ');
      final tail = switch (m[5]) {
        'NEXT LAP' => ' (다음 랩 적용)',
        'NEXT LAP PIT' => ' (다음 랩 · 피트인)',
        'PIT' => ' (피트인 랩)',
        _ => '',
      };
      return '$cars $what 삭제 — $reason, $where$tail';
    },
  ),
  _Rule(
    _re(r'§ TIME ([\d:.]+) WILL BE REINSTATED'),
    (m, cars) => '$cars 랩타임 ${m[1]} 복원',
  ),
  _Rule(
    _re(r'LAP TIME OF § - UNDER REVIEW'),
    (m, cars) => '$cars 랩타임 검토 중',
  ),

  // ── 사건·조사 ───────────────────────────────────────────────────────
  _Rule(
    _re(
      r'(FIA STEWARDS: )?(?:(.+?) )?INCIDENT INVOLVING §'
      r'(?: (NOTED|UNDER INVESTIGATION|WILL BE INVESTIGATED AFTER THE (?:SESSION|RACE|SPRINT)|'
      r'REVIEWED NO FURTHER INVESTIGATION|REVIEWED NO FURTHER ACTION|NO FURTHER ACTION))?'
      r'(?: - (.+?))?'
      r'(?: \(\d{1,2}:\d{2}(?::\d{2})?\)| \d{1,2}:\d{2}:\d{2})?',
    ),
    (m, cars) {
      final where = _incidentLocation(m[2]);
      if (m[2] != null && where == null) return null;
      final status = _incidentStatus[m[3]] ?? '';
      final head = [
        if (m[1] != null) '[스튜어드]',
        ?where,
        '$cars 관련 사건',
        if (status.isNotEmpty) status,
      ].join(' ');
      final reason = m[4];
      return reason == null ? head : _withReason(head, reason);
    },
  ),

  // ── 페널티 ─────────────────────────────────────────────────────────
  _Rule(
    _re(
      r'FIA STEWARDS: (PENALTY SERVED - )?(.+?) FOR §(?: - (.+?))?'
      r'(?: \(\d{1,2}:\d{2}(?::\d{2})?\)| \d{1,2}:\d{2}:\d{2})?',
    ),
    (m, cars) {
      final penalty = _penalty(m[2]!);
      if (penalty == null) return null;
      if (m[1] != null) return '$cars $penalty 이행 완료';
      final head = '[스튜어드] $cars $penalty';
      return m[3] == null ? head : _withReason(head, m[3]!);
    },
  ),

  // ── 세이프티카 ─────────────────────────────────────────────────────
  _Rule(_re(r'SAFETY CAR DEPLOYED'), (m, _) => '세이프티카 투입'),
  _Rule(_re(r'SAFETY CAR IN THIS LAP'), (m, _) => '이번 랩 세이프티카 복귀'),
  _Rule(_re(r'SAFETY CAR LIGHTS ON'), (m, _) => '세이프티카 경광등 점등'),
  _Rule(_re(r'SAFETY CAR LIGHTS OFF'), (m, _) => '세이프티카 경광등 소등 — 이번 랩 복귀'),
  _Rule(_re(r'SAFETY CAR THROUGH THE PIT LANE'), (m, _) => '세이프티카 피트레인 통과'),
  _Rule(
    _re(r'ALL CARS TO FOLLOW THE SAFETY CAR THROUGH THE PIT LANE'),
    (m, _) => '전 차량 세이프티카 따라 피트레인 통과',
  ),
  _Rule(_re(r'ALL CARS THROUGH THE PIT LANE'), (m, _) => '전 차량 피트레인 통과'),
  _Rule(
    _re(r'(?:SAFETY CAR|ALL CARS) (?:WILL )?USE START/FINISH STRAIGHT'),
    (m, _) => '스타트/피니시 직선 사용',
  ),
  _Rule(
    _re(r'LAPPED CARS? MAY NOW OVERTAKE THE SAFETY CAR(?:: (.+))?'),
    (m, _) => m[1] == null
        ? '랩다운 차량 세이프티카 추월 허용'
        : '랩다운 차량 세이프티카 추월 허용: ${_numberList(m[1]!)}',
  ),
  _Rule(_re(r'(?:VSC|VIRTUAL SAFETY CAR) DEPLOYED'), (m, _) => '버추얼 세이프티카(VSC) 발령'),
  _Rule(_re(r'(?:VSC|VIRTUAL SAFETY CAR) ENDING'), (m, _) => 'VSC 종료 예정'),
  _Rule(_re(r'MEDICAL CAR DEPLOYED'), (m, _) => '메디컬 카 출동'),

  // ── 피트 ───────────────────────────────────────────────────────────
  _Rule(_re(r'GREEN LIGHT - PIT EXIT OPEN'), (m, _) => '피트 출구 개방 (그린 라이트)'),
  _Rule(_re(r'PIT EXIT OPEN'), (m, _) => '피트 출구 개방'),
  _Rule(_re(r'PIT EXIT CLOSED'), (m, _) => '피트 출구 폐쇄'),
  _Rule(_re(r'PIT LANE ENTRY OPEN'), (m, _) => '피트 입구 개방'),
  _Rule(_re(r'PIT LANE ENTRY CLOSED'), (m, _) => '피트 입구 폐쇄'),
  _Rule(_re(r'PIT LANE CLEAR'), (m, _) => '피트레인 클리어'),
  _Rule(
    _re(r'ALL PASS HOLDERS MAY ACCESS THE PIT LANE'),
    (m, _) => '모든 패스 소지자 피트레인 출입 가능',
  ),

  // ── DRS / 2026 오버테이크·직선 모드 ───────────────────────────────
  _Rule(_re(r'DRS ENABLED'), (m, _) => 'DRS 사용 가능'),
  _Rule(_re(r'DRS DISABLED'), (m, _) => 'DRS 사용 불가'),
  _Rule(_re(r'DRS ENABLED IN ZONE (\d+)'), (m, _) => 'DRS ${m[1]}구역 사용 가능'),
  _Rule(_re(r'DRS DISABLED IN ZONE (\d+)'), (m, _) => 'DRS ${m[1]}구역 사용 불가'),
  _Rule(_re(r'OVERTAKE ENABLED'), (m, _) => '오버테이크 모드 사용 가능'),
  _Rule(_re(r'OVERTAKE DISABLED'), (m, _) => '오버테이크 모드 사용 불가'),
  _Rule(_re(r'STRAIGHT MODE - NORMAL GRIP'), (m, _) => '직선 모드 — 정상 그립'),
  _Rule(_re(r'STRAIGHT MODE - LOW GRIP'), (m, _) => '직선 모드 — 저그립'),
  _Rule(_re(r'STRAIGHT MODE - DISABLED'), (m, _) => '직선 모드 사용 불가'),

  // ── 노면·트랙 ──────────────────────────────────────────────────────
  _Rule(
    _re(r'TRACK SURFACE SLIPPERY IN TRACK SECTOR (\d+)'),
    (m, _) => '섹터 ${m[1]} 노면 미끄러움',
  ),
  _Rule(_re(r'LOW GRIP CONDITIONS'), (m, _) => '저그립 노면'),
  _Rule(_re(r'NORMAL GRIP CONDITIONS'), (m, _) => '정상 그립 노면'),
  _Rule(_re(r'LOW GRIP DELTA ACTIVE'), (m, _) => '저그립 델타 적용'),
  _Rule(_re(r'NORMAL GRIP DELTA ACTIVE'), (m, _) => '정상 그립 델타 적용'),
  _Rule(_re(r'WET TRACK'), (m, _) => '젖은 노면'),
  _Rule(_re(r'CHANGE IN CLIMATIC CONDITIONS'), (m, _) => '기상 조건 변화'),
  _Rule(
    _re(r'MARSHALS ON TRACK (?:AT|BEFORE) (TURN \d+|PIT ENTRY|PIT EXIT)'),
    (m, _) => '${_incidentLocation(m[1])} 마셜 투입',
  ),
  _Rule(
    _re(r'RECOVERY VEHICLE (?:ON TRACK )?(?:AT|BEFORE|IN) (TURN \d+|PIT ENTRY|PIT EXIT)'),
    (m, _) => '${_incidentLocation(m[1])} 회수 차량 투입',
  ),
  _Rule(_re(r'TRACK TEST COMPLETED'), (m, _) => '트랙 점검 완료'),
  _Rule(
    _re(r'RISK OF RAIN FOR (?:THE |THIS )?(?:F1 )?(.+?) IS (\d+) ?%'),
    (m, _) {
      final session = _sessionName(m[1]!);
      return session == null ? null : '$session 강수 확률 ${m[2]}%';
    },
  ),

  // ── 세션 진행 ──────────────────────────────────────────────────────
  _Rule(
    _re(r'(SESSION|RACE|SPRINT|S?Q\d) WILL RESUME AT (\d{1,2}:\d{2})'),
    (m, _) => '${_sessionName(m[1]!)} 재개 예정 (현지 ${m[2]})',
  ),
  _Rule(
    _re(r'(S?Q\d|SESSION|SPRINT|RACE|FORMATION LAP) WILL START AT (\d{1,2}:\d{2})'),
    (m, _) => '${_sessionName(m[1]!)} 시작 예정 (현지 ${m[2]})',
  ),
  _Rule(
    _re(r'SESSION WILL END AT (\d{1,2}:\d{2})'),
    (m, _) => '세션 종료 예정 (현지 ${m[1]})',
  ),
  _Rule(
    _re(r'ESTIMATED TIME OF (.+?) (START|RESUMPTION) - (\d{1,2}:\d{2})'),
    (m, _) {
      final session = _sessionName(m[1]!);
      if (session == null) return null;
      final what = m[2] == 'START' ? '시작' : '재개';
      return '$session $what 예상 (현지 ${m[3]})';
    },
  ),
  _Rule(
    _re(r'START OF (.+?) WILL BE DELAYED'),
    (m, _) {
      final session = _sessionName(m[1]!);
      return session == null ? null : '$session 시작 지연';
    },
  ),
  _Rule(_re(r'SESSION WILL NOT BE RESUMED'), (m, _) => '세션 재개 없음'),
  _Rule(_re(r'STANDING START'), (m, _) => '스탠딩 스타트'),
  _Rule(_re(r'ROLLING START(?: PROCEDURE)?'), (m, _) => '롤링 스타트'),
  _Rule(_re(r'EXTRA FORMATION LAP'), (m, _) => '포메이션 랩 추가'),
  _Rule(_re(r'RACE START'), (m, _) => '레이스 스타트'),
  _Rule(_re(r'SPRINT START'), (m, _) => '스프린트 스타트'),
  _Rule(_re(r'DELAYED START'), (m, _) => '스타트 지연'),
  _Rule(_re(r'ABORTED START'), (m, _) => '스타트 중단'),
  _Rule(_re(r'STARTING PROCEDURE SUSPENDED'), (m, _) => '스타트 절차 중단'),
  _Rule(
    _re(r'(?:FORMATION LAP WILL BE STARTED BEHIND THE SAFETY CAR|FORMATION LAP\(S\) BEHIND SAFETY CAR)'),
    (m, _) => '세이프티카 뒤에서 포메이션 랩 진행',
  ),
  _Rule(
    _re(r'RACE WILL START BEHIND THE SAFETY CAR'),
    (m, _) => '세이프티카 뒤에서 레이스 스타트',
  ),
  _Rule(_re(r'NO PRACTICE STARTS'), (m, _) => '연습 스타트 금지'),
  _Rule(
    _re(r'(?:RESUMPTION ORDER|ORDER FOR RESTART): (.+)'),
    (m, _) => '재개 순서: ${_numberList(m[1]!)}',
  ),
  _Rule(
    _re(r'(PINK|BLUE|LIGHT BLUE) HEAD PADDING MATERIAL MUST BE USED'),
    (m, _) => '헤드 패딩 ${_paddingColor[m[1]]} 사양 사용 의무',
  ),
  _Rule(_re(r'AWNINGS MAY BE USED'), (m, _) => '차양막 사용 허용'),
];

String? _withReason(String head, String reason) {
  final ko = _reason(reason);
  return ko == null ? null : '$head — $ko';
}

/// 사유. "FAILING TO FOLLOW RACE DIRECTORS INSTRUCTIONS - MAXIMUM DELTA TIME" 처럼
/// "주 사유 - 세부" 로 오는 경우가 많아 각각 번역한다. 하나라도 모르면 null.
String? _reason(String raw) {
  var reason = raw.trim();
  // "TRACK LIMITS (5TH OFFENCE)", "TRACK LIMITS (SQ1)" 같은 괄호 꼬리.
  String? suffix;
  final paren = RegExp(r' \((\d+)(?:ST|ND|RD|TH) OFFENCE\)$').firstMatch(reason);
  if (paren != null) {
    suffix = ' (${paren[1]}회째)';
    reason = reason.substring(0, paren.start);
  } else {
    final part = RegExp(r' \((S?Q\d)\)$').firstMatch(reason);
    if (part != null) {
      suffix = ' (${part[1]})';
      reason = reason.substring(0, part.start);
    }
  }
  final whole = _reasons[reason];
  if (whole != null) return whole + (suffix ?? '');
  final pieces = reason.split(' - ');
  final translated = pieces.map((p) => _reasons[p.trim()]).toList();
  if (translated.contains(null)) return null;
  return translated.join(' · ') + (suffix ?? '');
}

const Map<String, String> _reasons = {
  'FAILING TO FOLLOW RACE DIRECTORS INSTRUCTIONS': '레이스 디렉터 지시 불이행',
  'MAXIMUM DELTA TIME': '최대 델타 타임 초과',
  'ESCAPE ROAD INSTRUCTIONS': '탈출로 지시 위반',
  'PRACTICE START INFRINGEMENT': '연습 스타트 위반',
  'PRACTICE STARTS': '연습 스타트 위반',
  'CROSSING THE LINE AT PIT EXIT': '피트 출구 라인 침범',
  'CROSSING THE LINE AT PIT ENTRY': '피트 입구 라인 침범',
  'LEAVING GARAGE BEFORE RESUMPTION TIME ANNOUNCED': '재개 시각 발표 전 개러지 출발',
  'ENTERING THE FAST LANE BEFORE RESUMPTION TIME ANNOUNCED': '재개 시각 발표 전 패스트 레인 진입',
  'ENTERING FAST LANE': '패스트 레인 진입',
  'DRIVER WEIGHING': '드라이버 계체 불응',
  'CAUSING A COLLISION': '충돌 유발',
  'YELLOW FLAG INFRINGEMENT': '옐로 플래그 위반',
  'FAILING TO SLOW UNDER YELLOW FLAGS': '옐로 플래그 감속 위반',
  'IMPEDING': '진로 방해',
  'LEAVING THE TRACK AND GAINING AN ADVANTAGE': '트랙 이탈로 이득',
  'LEAVING THE TRACK MULTIPLE TIMES AND GAINING AN ADVANTAGE': '반복 트랙 이탈로 이득',
  'UNSAFE RELEASE': '위험한 릴리스',
  'FORCING ANOTHER DRIVER OFF THE TRACK': '상대를 트랙 밖으로 밀어냄',
  'SPEEDING IN THE PIT LANE': '피트레인 과속',
  'SAFETY CAR INFRINGEMENT': '세이프티카 규정 위반',
  'SAFETY CAR PROCEDURE INFRINGEMENT': '세이프티카 절차 위반',
  'VSC INFRINGEMENT': 'VSC 규정 위반',
  'UNSAFE CONDITION': '위험한 차량 상태',
  'TRACK LIMITS': '트랙 리밋',
  'DRIVING ERRATICALLY': '불규칙한 주행',
  'RED FLAG INFRINGEMENT': '레드 플래그 위반',
  'STARTING PROCEDURE INFRINGEMENT': '스타트 절차 위반',
  'OUT OF POSITION AT SAFETY CAR LINE': '세이프티카 라인 위치 위반',
  'FALSE START': '부정 출발',
  'MOVING BEFORE SIGNAL': '신호 전 출발',
  'OUT OF POSITION': '그리드 위치 이탈',
  'MOVING UNDER BRAKING': '브레이킹 중 진로 변경',
  'MORE THAN ONE CHANGE OF DIRECTION': '2회 이상 진로 변경',
  'PIT LANE INFRINGEMENT': '피트레인 규정 위반',
  'IGNORING BLUE FLAGS': '블루 플래그 무시',
  'REJOINING UNSAFELY': '위험한 트랙 복귀',
  'LEAVING PIT EXIT ON RED LIGHT': '피트 출구 적신호 위반',
  'FAILING TO SERVE TIME PENALTY CORRECTLY': '타임 페널티 이행 위반',
  'DRIVING UNNECESSARILY SLOWLY': '불필요한 저속 주행',
  'DRS INFRINGEMENT': 'DRS 규정 위반',
  'CAR SAFETY LIGHTS': '차량 안전등 규정 위반',
};

const Map<String, String> _deletionReasons = {
  'TRACK LIMITS': '트랙 리밋',
  'DOUBLE YELLOW': '더블 옐로 구간',
  'YELLOW FLAG': '옐로 플래그 구간',
  'RED FLAG': '레드 플래그',
};

const Map<String, String> _incidentStatus = {
  'NOTED': '기록',
  'UNDER INVESTIGATION': '조사 중',
  'WILL BE INVESTIGATED AFTER THE SESSION': '세션 후 조사',
  'WILL BE INVESTIGATED AFTER THE RACE': '레이스 후 조사',
  'WILL BE INVESTIGATED AFTER THE SPRINT': '스프린트 후 조사',
  'REVIEWED NO FURTHER INVESTIGATION': '검토 결과 추가 조사 없음',
  'REVIEWED NO FURTHER ACTION': '검토 결과 조치 없음',
  'NO FURTHER ACTION': '조치 없음',
};

const Map<String, String> _paddingColor = {
  'PINK': '핑크',
  'BLUE': '블루',
  'LIGHT BLUE': '라이트 블루',
};

/// 사건 위치. "TURN 4", "LAP 12 TURN 3", "TURNS 9 TO 11", "SQ1 - TURN 4",
/// "START/FINISH STRAIGHT" 처럼 조각이 이어 붙어 오므로 앞에서부터 하나씩
/// 떼어 번역한다. 모르는 조각이 남으면 null(→ 원문 표시).
String? _incidentLocation(String? raw) {
  if (raw == null) return null;
  var rest = raw.replaceAll(' - ', ' ').trim();
  final parts = <String>[];
  while (rest.isNotEmpty) {
    String? piece;
    Match? match;
    for (final entry in _locationTokens.entries) {
      match = entry.key.matchAsPrefix(rest);
      if (match != null) {
        piece = entry.value(match);
        break;
      }
    }
    if (piece == null || match == null) return null;
    parts.add(piece);
    rest = rest.substring(match.end).trim();
  }
  return parts.join(' ');
}

final Map<RegExp, String Function(Match m)> _locationTokens = {
  RegExp(r'TURNS (\d+) TO (\d+)'): (m) => '${m[1]}~${m[2]}번 코너',
  RegExp(r'TURN (\d+)'): (m) => '${m[1]}번 코너',
  RegExp(r'LAP (\d+)'): (m) => '${m[1]}랩',
  // Q1/SQ2 등은 그대로가 더 익숙하다.
  RegExp(r'(S?Q\d)'): (m) => m[1]!,
  RegExp(r'START/FINISH STRAIGHT'): (m) => '메인 직선',
  RegExp(r'PIT LANE'): (m) => '피트레인',
  RegExp(r'PIT ENTRY'): (m) => '피트 입구',
  RegExp(r'PIT EXIT'): (m) => '피트 출구',
};

String? _penalty(String raw) {
  final seconds = RegExp(r'^(\d+) SECOND TIME PENALTY$').firstMatch(raw);
  if (seconds != null) return '${seconds[1]}초 타임 페널티';
  final stopGo = RegExp(r'^(\d+) SECOND STOP/GO PENALTY$').firstMatch(raw);
  if (stopGo != null) return '${stopGo[1]}초 스톱 앤 고 페널티';
  final grid = RegExp(r'^(\d+) PLACE GRID PENALTY$').firstMatch(raw);
  if (grid != null) return '그리드 ${grid[1]}계단 강등';
  return switch (raw) {
    'DRIVE THROUGH PENALTY' => '드라이브 스루 페널티',
    'STOP-AND-GO PENALTY' || 'STOP AND GO PENALTY' => '스톱 앤 고 페널티',
    'WARNING' => '경고',
    'REPRIMAND' || 'REPRIMAND (DRIVING)' => '견책',
    'DISQUALIFIED' => '실격',
    _ => null,
  };
}

String? _sessionName(String raw) {
  final q = RegExp(r'^(S?Q)(\d)$').firstMatch(raw);
  if (q != null) return '${q[1]}${q[2]}';
  final fp = RegExp(r'^FREE PRACTICE (\d)$').firstMatch(raw);
  if (fp != null) return 'FP${fp[1]}';
  return switch (raw) {
    'SESSION' => '세션',
    'RACE' => '레이스',
    'SPRINT' => '스프린트',
    'QUALIFYING' || 'QUALIFYING SESSION' => '퀄리파잉',
    'SPRINT RACE' => '스프린트',
    'FORMATION LAP' => '포메이션 랩',
    'PRACTICE SESSION' => '연습 세션',
    'PM SESSION' => '오후 세션',
    'AM SESSION' => '오전 세션',
    'SPRINT QUALIFYING' || 'SPRINT SHOOTOUT' => '스프린트 퀄리파잉',
    'FIRST PRACTICE SESSION' => 'FP1',
    'SECOND PRACTICE SESSION' => 'FP2',
    'THIRD PRACTICE SESSION' => 'FP3',
    _ => null,
  };
}

String _numberList(String raw) =>
    RegExp(r'\d+').allMatches(raw).map((m) => m[0]).join(', ');
