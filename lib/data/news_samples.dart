import '../models/news_item.dart';

/// 소식 탭 개발/테스트용 로컬 샘플 데이터([SampleNewsRepository]에서 사용).
/// 발행 시각은 [now] 기준 상대 시간으로 만들어 '2시간 전' 같은 표시가
/// 데모에서 자연스럽게 보이게 한다. 실서비스 UX 와 동일하게 한국어
/// 제목(titleKo)을 포함한다 — 앱은 영어 원문 제목을 표시하지 않는다.
List<NewsItem> buildSampleNewsItems([DateTime? now]) {
  final base = now ?? DateTime.now();

  NewsItem item({
    required int index,
    required String sourceName,
    required String title,
    required String titleKo,
    required String briefKo,
    required Duration age,
    List<String> tags = const [],
  }) {
    final publishedAt = base.subtract(age);
    return NewsItem(
      id: 'sample-${index.toString().padLeft(3, '0')}',
      sourceName: sourceName,
      originalTitle: title,
      titleKo: titleKo,
      // 샘플은 매체 홈으로 연결(실데이터에서는 기사 원문 링크).
      originalLink: _sourceHomeUrl[sourceName] ?? 'https://www.formula1.com',
      publishedAt: publishedAt,
      fetchedAt: publishedAt.add(const Duration(minutes: 10)),
      aiBriefKo: briefKo,
      tags: tags,
      hash: 'sample-hash-$index',
    );
  }

  return [
    item(
      index: 1,
      sourceName: 'Motorsport.com',
      title: 'Leclerc holds off Russell in Silverstone thriller',
      titleKo: '르클레르, 실버스톤 접전 끝에 러셀 막고 우승',
      briefKo:
          '르클레르가 실버스톤에서 러셀의 막판 추격을 0.4초 차로 막아내며 시즌 3승째를 거뒀습니다. '
          '페라리는 이번 승리로 컨스트럭터 선두와의 격차를 12점으로 좁혔습니다.',
      age: const Duration(hours: 2),
      tags: const ['르클레르', '페라리', '영국 GP'],
    ),
    item(
      index: 2,
      sourceName: 'Autosport',
      title: 'Hamilton: podium proves Ferrari upgrade direction is right',
      titleKo: '해밀턴 "포디움이 페라리 업그레이드 방향 증명"',
      briefKo:
          '해밀턴이 영국 GP 3위 이후 "업그레이드 방향이 옳다는 증거"라고 말했습니다. '
          '페라리는 스파에 추가 업데이트를 투입할 예정입니다.',
      age: const Duration(hours: 4),
      tags: const ['해밀턴', '페라리'],
    ),
    item(
      index: 3,
      sourceName: 'The Race',
      title: 'Why McLaren\'s home race unravelled in 10 laps',
      titleKo: '맥라렌 홈 레이스, 10랩 만에 무너진 이유는 전략',
      briefKo:
          '맥라렌이 홈 레이스에서 전략 실수와 피트스톱 지연으로 더블 포디움 기회를 놓쳤습니다. '
          '노리스는 5위, 피아스트리는 7위로 마쳤습니다.',
      age: const Duration(hours: 6),
      tags: const ['맥라렌', '노리스', '영국 GP'],
    ),
    item(
      index: 4,
      sourceName: 'Formula1.com',
      title: 'Antonelli takes maiden pole in mixed conditions',
      titleKo: '안토넬리, 혼돈의 퀄리파잉에서 데뷔 첫 폴포지션',
      briefKo:
          '안토넬리가 변덕스러운 날씨 속 퀄리파잉에서 데뷔 첫 폴포지션을 차지했습니다. '
          '메르세데스 신인의 최연소 폴 기록 경신입니다.',
      age: const Duration(hours: 20),
      tags: const ['안토넬리', '메르세데스', '영국 GP'],
    ),
    item(
      index: 5,
      sourceName: 'RaceFans',
      title: 'FIA confirms 2027 engine regulation timeline',
      titleKo: 'FIA, 2027 엔진 규정 확정 일정 발표',
      briefKo:
          'FIA가 2027 파워유닛 규정 확정 일정을 발표했습니다. '
          '지속가능 연료 100% 전환과 전기 출력 비중 확대가 핵심입니다.',
      age: const Duration(days: 1, hours: 3),
      tags: const ['FIA', '규정'],
    ),
    item(
      index: 6,
      sourceName: 'Motorsport.com',
      title: 'Verstappen frustrated by Red Bull\'s slow-corner weakness',
      titleKo: '베르스타펜, 레드불 저속 코너 약점에 답답함 토로',
      briefKo:
          '베르스타펜이 레드불의 저속 코너 약점에 대해 "우승 경쟁을 하려면 근본적인 해결이 필요하다"고 지적했습니다. '
          '레드불은 헝가리 전까지 서스펜션 개선을 목표로 하고 있습니다.',
      age: const Duration(days: 1, hours: 8),
      tags: const ['베르스타펜', '레드불'],
    ),
    item(
      index: 7,
      sourceName: 'PlanetF1',
      title: 'Audi handed upgrade boost ahead of Spa',
      titleKo: '아우디, 스파부터 새 플로어 패키지 투입',
      briefKo:
          '아우디가 스파부터 새 플로어 패키지를 투입합니다. '
          '휠켄베르크는 "중위권 싸움의 전환점이 될 것"이라고 기대를 밝혔습니다.',
      age: const Duration(days: 2, hours: 1),
      tags: const ['아우디', '휠켄베르크'],
    ),
    item(
      index: 8,
      sourceName: 'Autosport',
      title: 'Sprint format tweaks under discussion for 2027',
      titleKo: '2027 스프린트 포맷 개편 논의 진행 중',
      briefKo:
          'F1이 2027년 스프린트 포맷 개편을 논의 중입니다. '
          '리버스 그리드 대신 별도 퀄리파잉 유지가 유력한 것으로 알려졌습니다.',
      age: const Duration(days: 2, hours: 9),
      tags: const ['스프린트', '규정'],
    ),
    item(
      index: 9,
      sourceName: 'The Race',
      title: 'Williams extends Albon contract to 2028',
      titleKo: '윌리엄스, 알본과 2028년까지 재계약',
      briefKo:
          '윌리엄스가 알본과 2028년까지 계약을 연장했습니다. '
          '알본은 "프로젝트의 성장 궤도를 믿는다"고 말했습니다.',
      age: const Duration(days: 3, hours: 2),
      tags: const ['알본', '윌리엄스'],
    ),
    item(
      index: 10,
      sourceName: 'Formula1.com',
      title: 'Tsunoda cleared after heavy FP3 crash',
      titleKo: '츠노다, FP3 대형 사고 후 출전 허가',
      briefKo:
          '츠노다가 FP3 대형 사고 후 메디컬 체크를 통과해 퀄리파잉에 출전했습니다. '
          '섀시는 교체됐고 그리드 페널티는 없습니다.',
      age: const Duration(days: 3, hours: 6),
      tags: const ['츠노다', '레드불'],
    ),
    item(
      index: 11,
      sourceName: 'RaceFans',
      title: 'Aston Martin\'s Newey-designed 2027 car "on schedule"',
      titleKo: '뉴이 설계 애스턴 마틴 2027 차량 "일정대로"',
      briefKo:
          '애스턴 마틴이 뉴이가 설계를 주도하는 2027년 차량 개발이 일정대로 진행 중이라고 밝혔습니다. '
          '알론소는 계약 연장 여부를 시즌 말에 결정할 예정입니다.',
      age: const Duration(days: 4, hours: 5),
      tags: const ['애스턴 마틴', '알론소'],
    ),
    item(
      index: 12,
      sourceName: 'Motorsport.com',
      title: 'Korean GP feasibility study confirmed by promoter',
      titleKo: '한국 그랑프리 유치 타당성 조사 공식 확인',
      briefKo:
          '한국 그랑프리 유치를 위한 타당성 조사가 공식 확인됐습니다. '
          '2029년 이후 캘린더 합류를 목표로 인천과 부산이 후보지로 거론됩니다.',
      age: const Duration(days: 4, hours: 20),
      tags: const ['한국 GP', '캘린더'],
    ),
    item(
      index: 13,
      sourceName: 'PlanetF1',
      title: 'Gasly: Alpine progress masked by qualifying woes',
      titleKo: '가슬리 "알핀의 발전, 퀄리파잉이 가리고 있다"',
      briefKo:
          '가슬리가 알핀의 레이스 페이스는 개선됐지만 퀄리파잉 한 랩이 발목을 잡고 있다고 분석했습니다. '
          '팀은 새 리어윙으로 해결을 노립니다.',
      age: const Duration(days: 5, hours: 4),
      tags: const ['가슬리', '알핀'],
    ),
    item(
      index: 14,
      sourceName: 'Autosport',
      title: 'Haas rookie Lindblad impresses in first F1 test',
      titleKo: '하스 신인 린드블라드, 첫 F1 테스트서 눈도장',
      briefKo:
          '린드블라드가 하스 테스트에서 인상적인 페이스를 보였습니다. '
          '내년 시트 경쟁에서 유리한 고지를 점했다는 평가입니다.',
      age: const Duration(days: 5, hours: 22),
      tags: const ['린드블라드', '하스'],
    ),
    item(
      index: 15,
      sourceName: 'The Race',
      title: 'The data behind Mercedes\' race-pace resurgence',
      titleKo: '데이터로 본 메르세데스 레이스 페이스 반등',
      briefKo:
          '메르세데스의 최근 3개 그랑프리 레이스 페이스가 선두권과 대등해졌다는 데이터 분석입니다. '
          '타이어 관리 개선이 핵심 요인으로 꼽힙니다.',
      age: const Duration(days: 6, hours: 3),
      tags: const ['메르세데스'],
    ),
    item(
      index: 16,
      sourceName: 'Formula1.com',
      title: 'Spa weather warning: rain likely for race day',
      titleKo: '벨기에 GP 레이스 데이 비 예보',
      briefKo:
          '벨기에 GP 레이스 데이에 비 예보가 나왔습니다. '
          '스파 특유의 국지성 소나기로 전략 변수가 커질 전망입니다.',
      age: const Duration(days: 6, hours: 12),
      tags: const ['벨기에 GP'],
    ),
    item(
      index: 17,
      sourceName: 'RaceFans',
      title: 'Stroll penalty upheld after Aston Martin appeal fails',
      titleKo: '스트롤 페널티 유지, 애스턴 마틴 이의 기각',
      briefKo:
          '스트롤의 영국 GP 5초 페널티에 대한 애스턴 마틴의 이의 제기가 기각됐습니다. '
          '최종 순위 변동은 없습니다.',
      age: const Duration(days: 7, hours: 1),
      tags: const ['스트롤', '애스턴 마틴'],
    ),
    item(
      index: 18,
      sourceName: 'Motorsport.com',
      title: 'Bearman: Haas must convert Friday pace into points',
      titleKo: '베어먼 "하스, 금요일 페이스를 포인트로 바꿔야"',
      briefKo:
          '베어먼이 하스의 금요일 페이스를 일요일 포인트로 연결하지 못하는 문제를 지적했습니다. '
          '팀은 레이스 셋업 방향 재검토에 들어갔습니다.',
      age: const Duration(days: 7, hours: 18),
      tags: const ['베어먼', '하스'],
    ),
    item(
      index: 19,
      sourceName: 'PlanetF1',
      title: 'F1 viewership hits record high in first half of 2026',
      titleKo: '2026 상반기 F1 시청자 수 역대 최고 기록',
      briefKo:
          '2026 시즌 상반기 F1 글로벌 시청자 수가 역대 최고치를 기록했습니다. '
          '신규 규정 도입과 접전 양상이 흥행 요인으로 분석됩니다.',
      age: const Duration(days: 8, hours: 6),
      tags: const ['F1'],
    ),
    item(
      index: 20,
      sourceName: 'Autosport',
      title: 'Colapinto keeps seat as Alpine confirms line-up stability',
      titleKo: '알핀, 콜라핀토 시트 유지 공식화',
      briefKo:
          '알핀이 시즌 잔여 경기 콜라핀토 체제 유지를 공식화했습니다. '
          '드라이버 시장 루머를 일축한 결정입니다.',
      age: const Duration(days: 9, hours: 2),
      tags: const ['콜라핀토', '알핀'],
    ),
  ];
}

const Map<String, String> _sourceHomeUrl = {
  'Motorsport.com': 'https://www.motorsport.com',
  'Autosport': 'https://www.autosport.com',
  'The Race': 'https://www.the-race.com',
  'RaceFans': 'https://www.racefans.net',
  'Formula1.com': 'https://www.formula1.com',
  'PlanetF1': 'https://www.planetf1.com',
};
