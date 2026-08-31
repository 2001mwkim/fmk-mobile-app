import '../models/gp_guide.dart';

/// 그랑프리별 관전 가이드 정적 데이터 (raceId 키).
///
/// - 타이어: 피렐리 공식 발표(2026 시즌은 C1~C5, C6 미사용). 발표 전이면 null
///   — UI 가 "발표 예정" 으로 처리한다. 통상 각 GP 2~4주 전에 발표되므로
///   시즌 후반 라운드는 발표 후 여기에 채워 넣을 것.
/// - 랩 레코드: 결승 레이스 중 기록(퀄리 기록 아님), 2025 시즌 종료 기준.
/// - 최근 우승자: 2023~2025 (최신 먼저). 해당 연도 미개최면 그 연도는 없다.
/// - traits/watchPoints: 큐레이션 — 웹 매거진 톤의 짧은 한국어 문장.
const Map<String, GpGuide> gpGuideByRaceId = {
  'australia-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:19.813', driverKo: '샤를 르클레르', year: 2024),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '카를로스 사인츠', teamKo: '페라리'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 3, tyreStress: 3, overtaking: 4),
    watchPoints: [
      '공원 도로를 쓰는 반영구 서킷 — 벽이 가까워 세이프티카가 자주 나온다',
      '시즌 개막전. 겨울 테스트에서 감춰 온 각 팀의 진짜 폼이 처음 드러나는 무대',
      '9-10번 고속 시케인은 리어가 불안한 차를 가장 먼저 벌하는 구간',
    ],
  ),
  'china-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    lapRecord: GpLapRecord(time: '1:32.238', driverKo: '미하엘 슈마허', year: 2004),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 3, tyreStress: 4, overtaking: 2),
    watchPoints: [
      '1-2번 나선형 코너: 진입에서 계속 조여드는 롱 코너라 앞타이어가 극도로 혹사당한다',
      '1.2km 백스트레이트 끝 헤어핀은 시즌 최고의 추월 포인트 중 하나',
      '앞바퀴 그레이닝 관리가 스틴트 길이를 결정한다',
    ],
  ),
  'japan-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C1', medium: 'C2', soft: 'C3'),
    lapRecord: GpLapRecord(time: '1:30.965', driverKo: '키미 안토넬리', year: 2025),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 5, overtaking: 4),
    watchPoints: [
      '유일한 8자 레이아웃. 1섹터 S커브의 리듬이 랩타임 전체를 좌우한다',
      '드라이버들이 꼽는 최고 난도 코너 130R — 요즘 차로도 풀스로틀 한계 승부',
      '타이어 부하가 시즌 최상위권이라 2스톱 전략이 기본값',
    ],
  ),
  // 바레인 GP 는 세팡(말레이시아) 이전 개최(races.dart 주석 참고) —
  // 서킷 관련 항목(랩 레코드·특성·관전 포인트)은 세팡 기준, 최근 우승자는
  // 그랑프리 명칭 기준(사키르 개최 시절)이라 연도 옆 병기 없이 그대로 둔다.
  'bahrain': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    lapRecord: GpLapRecord(time: '1:34.080', driverKo: '제바스티안 페텔', year: 2017),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 4, overtaking: 2),
    watchPoints: [
      '2017년 이후 9년 만에 F1 이 돌아오는 세팡 — 현역 대부분이 처음 달리는 트랙',
      '마지막 두 스트레이트가 헤어핀으로 이어져 한 랩에 추월 기회가 두 번 온다',
      '열대 스콜 — 오후 소나기가 순식간에 트랙을 뒤집는 동남아 명물',
    ],
  ),
  // 2026 취소 — 개최 이력 참고용(타이어 없음).
  'saudi-arabia': GpGuide(
    lapRecord: GpLapRecord(time: '1:30.734', driverKo: '루이스 해밀턴', year: 2021),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '세르히오 페레즈', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 2, tyreStress: 3, overtaking: 3),
    watchPoints: [
      '평균 시속 250km/h 를 넘나드는 세계에서 가장 빠른 스트리트 서킷',
      '블라인드 고속 코너와 벽 사이 — 작은 실수가 곧 세이프티카',
    ],
  ),
  'miami-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:29.708', driverKo: '막스 베르스타펜', year: 2023),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 3, tyreStress: 3, overtaking: 3),
    watchPoints: [
      '고속 1섹터와 저속 시케인 섹터가 공존 — 셋업 타협이 어렵다',
      '플로리다 열기에 노면 온도가 50℃ 를 넘어 타이어 오버히트 관리가 관건',
      '11-16번 저속 구간에서 벌어진 간격을 백스트레이트에서 되갚는 그림이 반복된다',
    ],
  ),
  'canada-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:13.078', driverKo: '발테리 보타스', year: 2019),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '조지 러셀', teamKo: '메르세데스'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 2, tyreStress: 3, overtaking: 2),
    watchPoints: [
      '풀스로틀 → 급제동의 반복. 브레이크 냉각이 한계에 몰리는 트랙',
      '마지막 시케인 출구의 "월 오브 챔피언스" — 챔피언들도 박아 온 그 벽',
      '벽이 가깝고 날씨 변수가 커 세이프티카 확률이 높다',
    ],
  ),
  'monaco-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:12.909', driverKo: '루이스 해밀턴', year: 2021),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '샤를 르클레르', teamKo: '페라리'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 5, tyreStress: 1, overtaking: 5),
    watchPoints: [
      '추월이 사실상 불가능 — 토요일 퀄리파잉이 사실상의 결승이다',
      '순위 변동은 피트 타이밍(언더컷/오버컷)과 세이프티카에서 나온다',
      '가드레일까지 밀리미터 단위로 붙이는 시즌 최고의 집중력 승부',
    ],
  ),
  'barcelona-catalunya-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    lapRecord: GpLapRecord(time: '1:15.743', driverKo: '오스카 피아스트리', year: 2025),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 4, overtaking: 4),
    watchPoints: [
      '모든 팀이 데이터를 가장 많이 가진 트랙 — 차의 종합 완성도가 그대로 순위가 된다',
      '3번 고속 롱 코너에서 앞타이어 마모가 결정된다',
      '추월이 어려워 전략(스톱 수 차이)으로 순위를 바꾸는 그림이 많다',
    ],
  ),
  'austria-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:05.619', driverKo: '카를로스 사인츠', year: 2020),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '조지 러셀', teamKo: '메르세데스'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 2, tyreStress: 3, overtaking: 2),
    watchPoints: [
      '랩타임 65초 안팎의 짧은 트랙 — 퀄리에서 0.1초 안에 10대가 몰린다',
      '언덕 위 3-4번 헤어핀이 메인 추월 포인트',
      '마지막 두 고속 코너의 트랙 리미트 판정이 매년 논란의 중심',
    ],
  ),
  'great-britain-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C1', medium: 'C2', soft: 'C3'),
    lapRecord: GpLapRecord(time: '1:27.097', driverKo: '막스 베르스타펜', year: 2020),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '루이스 해밀턴', teamKo: '메르세데스'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 5, overtaking: 3),
    watchPoints: [
      '맥스 5g 를 넘는 콥스-매고츠-베케츠 고속 연속 코너 — F1 에어로의 정점',
      '횡가속이 시즌 최상위라 왼쪽 앞타이어가 가장 먼저 한계에 온다',
      '영국 날씨 — 소나기 한 번에 레이스가 통째로 뒤집힌다',
    ],
  ),
  'belgium-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    lapRecord: GpLapRecord(time: '1:44.701', driverKo: '세르히오 페레즈', year: 2024),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '루이스 해밀턴', teamKo: '메르세데스'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 2, tyreStress: 4, overtaking: 2),
    watchPoints: [
      '오 루즈-라디용을 전개로 케멜 스트레이트에서 승부가 나는 시즌 대표 추월 구간',
      '7km 트랙의 구간별 날씨가 달라 "한쪽만 비" 가 실제로 일어난다',
      '고속 코너 연속 부하로 타이어 블리스터링이 자주 등장한다',
    ],
  ),
  'hungary-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:16.627', driverKo: '루이스 해밀턴', year: 2020),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 5, tyreStress: 4, overtaking: 5),
    watchPoints: [
      '"벽 없는 모나코" — 코너가 쉼 없이 이어져 추월 창이 거의 없다',
      '한여름 부다페스트의 더위로 노면 온도와 체력 모두 한계 승부',
      '트랙 포지션이 절대적이라 언더컷 싸움이 가장 치열한 그랑프리',
    ],
  ),
  'netherlands-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    lapRecord: GpLapRecord(time: '1:11.097', driverKo: '루이스 해밀턴', year: 2021),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 3, overtaking: 4),
    watchPoints: [
      '3번·마지막 코너의 뱅크(경사 18도) — F1 에서 보기 드문 오벌식 코너링',
      '좁고 리듬감 있는 올드스쿨 레이아웃이라 퀄리 비중이 크다',
      '북해 바람이 방향을 바꿀 때마다 차 밸런스가 함께 흔들린다',
    ],
  ),
  'italy-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:20.901', driverKo: '랜도 노리스', year: 2025),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '샤를 르클레르', teamKo: '페라리'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 1, tyreStress: 2, overtaking: 1),
    watchPoints: [
      '"속도의 성전" — 시즌 최저 다운포스, 최고 최고속의 슬립스트림 승부',
      '피트 손실이 시즌 최상위라 원스톱이 기본, 타이어를 끝까지 버티는 쪽이 이긴다',
      '티포시의 홈 — 페라리가 유독 힘을 내는 무대',
    ],
  ),
  // 마드리드 신규 시가지 서킷(Madring) — 2026 첫 개최라 역대 기록이 없다.
  'spain-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C2', medium: 'C3', soft: 'C4'),
    traits: GpTraits(downforce: 4, tyreStress: 3, overtaking: 3),
    watchPoints: [
      '2026 년 캘린더 유일의 완전 신규 서킷 — 모든 팀이 데이터 제로에서 출발한다',
      '경사 24도의 대형 뱅크 코너 "라 모누멘탈" 이 최대 볼거리',
      '시가지+전용 구간 하이브리드 레이아웃, 시뮬레이터 준비가 잘 된 팀이 유리하다',
    ],
  ),
  'azerbaijan-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:43.009', driverKo: '샤를 르클레르', year: 2019),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '오스카 피아스트리', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '세르히오 페레즈', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 2, tyreStress: 2, overtaking: 1),
    watchPoints: [
      '2km 풀스로틀 구간 + 1번 코너 급제동 — 슬립스트림 추월의 교과서',
      '성벽 구간(8-12번)은 차 한 대 폭이 겨우 지나는 시즌 최협소 구간',
      '사고·세이프티카·레드 플래그가 단골이라 끝까지 결과를 알 수 없다',
    ],
  ),
  'singapore-2026': GpGuide(
    tyres: TyreAllocation(hard: 'C3', medium: 'C4', soft: 'C5'),
    lapRecord: GpLapRecord(time: '1:33.808', driverKo: '루이스 해밀턴', year: 2025),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '조지 러셀', teamKo: '메르세데스'),
      GpWinner(year: 2024, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '카를로스 사인츠', teamKo: '페라리'),
    ],
    traits: GpTraits(downforce: 5, tyreStress: 4, overtaking: 5),
    watchPoints: [
      '고온다습한 2시간 야간 레이스 — 드라이버 체중이 3kg 빠지는 시즌 최고 체력전',
      '벽에 둘러싸인 시가지라 세이프티카 확률이 시즌 최상위',
      '추월이 어려워 전략과 실수 유도가 순위를 만든다',
    ],
  ),
  // 미국 이후 라운드 타이어는 피렐리 미발표(발표되면 채울 것).
  'united-states-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:36.169', driverKo: '샤를 르클레르', year: 2019),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '샤를 르클레르', teamKo: '페라리'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 4, overtaking: 2),
    watchPoints: [
      '1섹터 고속 에스 구간은 실버스톤 매고츠-베케츠의 미국판',
      '언덕 위 1번 헤어핀 — 넓은 진입각 덕에 라인 여러 개로 승부가 갈린다',
      '울퉁불퉁한 노면(범프)이 차고 낮은 차를 괴롭힌다',
    ],
  ),
  'mexico-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:17.774', driverKo: '발테리 보타스', year: 2021),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '카를로스 사인츠', teamKo: '페라리'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 5, tyreStress: 3, overtaking: 3),
    watchPoints: [
      '해발 2,200m 의 얇은 공기 — 최대 윙을 달아도 다운포스는 몬자 수준, 냉각도 한계',
      '1.2km 스트레이트 끝 1-3번 복합 코너에서 대부분의 추월이 나온다',
      '경기장을 관통하는 스타디움 섹션의 응원 열기가 명물',
    ],
  ),
  'brazil-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:10.540', driverKo: '발테리 보타스', year: 2018),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 3, tyreStress: 3, overtaking: 2),
    watchPoints: [
      '급변하는 날씨의 대명사 — 비 예보가 있으면 무조건 챙겨 봐야 하는 그랑프리',
      '세나 S 진입의 슬립스트림 승부와 짧은 랩이 만드는 끊임없는 배틀',
      '역전 명승부의 성지(2008 해밀턴, 2021 해밀턴, 2024 베르스타펜)',
    ],
  ),
  'las-vegas-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:33.365', driverKo: '막스 베르스타펜', year: 2025),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '조지 러셀', teamKo: '메르세데스'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 1, tyreStress: 2, overtaking: 2),
    watchPoints: [
      '한밤 사막 기온(10℃ 안팎)에서 타이어 온도를 살리는 팀이 이긴다',
      '스트립 대로 1.9km 스트레이트 — 몬자급 저다운포스 셋업',
      '그레이닝이 시즌에서 가장 심하게 나오는 트랙',
    ],
  ),
  'qatar-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:22.384', driverKo: '랜도 노리스', year: 2024),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 4, tyreStress: 5, overtaking: 3),
    watchPoints: [
      '중고속 코너만 이어지는 원래 오토바이(MotoGP) 서킷 — 타이어 부하 시즌 최고 수준',
      '타이어 한계로 스틴트 길이 제한이 걸렸던 전례가 있어 전략 변수가 크다',
      '고속 코너에서의 차 밸런스 차이가 랩타임 격차로 직결된다',
    ],
  ),
  'abu-dhabi-2026': GpGuide(
    lapRecord: GpLapRecord(time: '1:25.637', driverKo: '케빈 마그누센', year: 2024),
    recentWinners: [
      GpWinner(year: 2025, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
      GpWinner(year: 2024, driverKo: '랜도 노리스', teamKo: '맥라렌'),
      GpWinner(year: 2023, driverKo: '막스 베르스타펜', teamKo: '레드불 레이싱'),
    ],
    traits: GpTraits(downforce: 3, tyreStress: 2, overtaking: 3),
    watchPoints: [
      '시즌 피날레 — 챔피언십이 여기까지 오면 모든 시선이 한 곳에 모인다',
      '석양에서 야간으로 넘어가는 트와일라잇 레이스, 노면 온도가 계속 떨어진다',
      '두 개의 긴 스트레이트 뒤 헤어핀이 메인 추월 포인트',
    ],
  ),
};

GpGuide? getGpGuide(String raceId) => gpGuideByRaceId[raceId];
