/// 드라이버·컨스트럭터 상세의 '프로필' 섹션용 고정 사실 데이터.
///
/// 출처: F1DB v2026.18.0 (https://github.com/f1db/f1db, CC BY 4.0) —
/// f1db-drivers / f1db-seasons-entrants-drivers(테스트 드라이버 제외 최초 출전
/// 연도) / f1db-seasons-entrants-constructors(2026 파워유닛).
///
/// 레이스마다 바뀌는 통산 기록(우승·포디움 등)은 일부러 넣지 않았다 — 앱에
/// 고정하면 다음 릴리스까지 틀린 값이 된다. 여기 값은 시즌 중 바뀌지 않는다.
/// 단, 챔피언 횟수는 **시즌이 끝나면** 갱신하고, 라인업이 바뀌면 항목을 추가할 것.
/// 출생지 한글 표기는 국립국어원 외래어 표기 기준으로 옮겼다.
library;

class DriverBio {
  const DriverBio({
    required this.birthDate,
    required this.birthPlaceKo,
    required this.number,
    required this.debutYear,
    this.championships = 0,
  });

  /// yyyy-MM-dd
  final String birthDate;

  /// "볼로냐, 이탈리아"
  final String birthPlaceKo;
  final int number;

  /// F1 결승 첫 출전 시즌.
  final int debutYear;

  /// 드라이버 월드 챔피언 횟수.
  final int championships;
}

class TeamBio {
  const TeamBio({required this.powerUnitKo, this.championships = 0});

  /// 2026 파워유닛 공급사.
  final String powerUnitKo;

  /// 컨스트럭터 챔피언 횟수(F1DB 컨스트럭터 기준).
  final int championships;
}

/// 드라이버 코드(TLA) → 프로필.
const Map<String, DriverBio> driverBiosByCode = {
  'ALB': DriverBio(
    birthDate: '1996-03-23',
    birthPlaceKo: '런던, 영국',
    number: 23,
    debutYear: 2019,
  ),
  'LIN': DriverBio(
    birthDate: '2007-08-08',
    birthPlaceKo: '버지니아 워터, 영국',
    number: 41,
    debutYear: 2026,
  ),
  'SAI': DriverBio(
    birthDate: '1994-09-01',
    birthPlaceKo: '마드리드, 스페인',
    number: 55,
    debutYear: 2015,
  ),
  'LEC': DriverBio(
    birthDate: '1997-10-16',
    birthPlaceKo: '몬테카를로, 모나코',
    number: 16,
    debutYear: 2018,
  ),
  'OCO': DriverBio(
    birthDate: '1996-09-17',
    birthPlaceKo: '에브뢰, 프랑스',
    number: 31,
    debutYear: 2016,
  ),
  'ALO': DriverBio(
    birthDate: '1981-07-29',
    birthPlaceKo: '오비에도, 스페인',
    number: 14,
    debutYear: 2001,
    championships: 2,
  ),
  'COL': DriverBio(
    birthDate: '2003-05-27',
    birthPlaceKo: '필라르, 아르헨티나',
    number: 43,
    debutYear: 2025,
  ),
  'BOR': DriverBio(
    birthDate: '2004-10-14',
    birthPlaceKo: '오자스쿠, 브라질',
    number: 5,
    debutYear: 2025,
  ),
  'RUS': DriverBio(
    birthDate: '1998-02-15',
    birthPlaceKo: '킹스린, 영국',
    number: 63,
    debutYear: 2019,
  ),
  'HAD': DriverBio(
    birthDate: '2004-09-28',
    birthPlaceKo: '파리, 프랑스',
    number: 6,
    debutYear: 2025,
  ),
  'ANT': DriverBio(
    birthDate: '2006-08-25',
    birthPlaceKo: '볼로냐, 이탈리아',
    number: 12,
    debutYear: 2025,
  ),
  'STR': DriverBio(
    birthDate: '1998-10-29',
    birthPlaceKo: '몬트리올, 캐나다',
    number: 18,
    debutYear: 2017,
  ),
  'NOR': DriverBio(
    birthDate: '1999-11-13',
    birthPlaceKo: '브리스틀, 영국',
    number: 4,
    debutYear: 2019,
    championships: 1,
  ),
  'HAM': DriverBio(
    birthDate: '1985-01-07',
    birthPlaceKo: '스티버니지, 영국',
    number: 44,
    debutYear: 2007,
    championships: 7,
  ),
  'LAW': DriverBio(
    birthDate: '2002-02-11',
    birthPlaceKo: '헤이스팅스, 뉴질랜드',
    number: 30,
    debutYear: 2023,
  ),
  'VER': DriverBio(
    birthDate: '1997-09-30',
    birthPlaceKo: '하셀트, 벨기에',
    number: 3,
    debutYear: 2015,
    championships: 4,
  ),
  'HUL': DriverBio(
    birthDate: '1987-08-19',
    birthPlaceKo: '에메리히암라인, 독일',
    number: 27,
    debutYear: 2010,
  ),
  'BEA': DriverBio(
    birthDate: '2005-05-08',
    birthPlaceKo: '헤이버링, 영국',
    number: 87,
    debutYear: 2025,
  ),
  'PIA': DriverBio(
    birthDate: '2001-04-06',
    birthPlaceKo: '멜버른, 호주',
    number: 81,
    debutYear: 2023,
  ),
  'GAS': DriverBio(
    birthDate: '1996-02-07',
    birthPlaceKo: '루앙, 프랑스',
    number: 10,
    debutYear: 2017,
  ),
  'PER': DriverBio(
    birthDate: '1990-01-26',
    birthPlaceKo: '과달라하라, 멕시코',
    number: 11,
    debutYear: 2011,
  ),
  'BOT': DriverBio(
    birthDate: '1989-08-28',
    birthPlaceKo: '나스톨라, 핀란드',
    number: 77,
    debutYear: 2013,
  ),
  'TSU': DriverBio(
    birthDate: '2000-05-11',
    birthPlaceKo: '사가미하라, 일본',
    number: 22,
    debutYear: 2021,
  ),
};

/// 팀 한글명(teamKo) → 프로필. 데뷔 연도는 뺐다 — F1DB 는 브랜드 기준이라
/// 애스턴 마틴 1959·레이싱 불스 2025 처럼 팬이 아는 팀 역사와 어긋난다.
const Map<String, TeamBio> teamBiosByKo = {
  '메르세데스': TeamBio(powerUnitKo: '메르세데스', championships: 8),
  '페라리': TeamBio(powerUnitKo: '페라리', championships: 16),
  '맥라렌': TeamBio(powerUnitKo: '메르세데스', championships: 10),
  '레드불 레이싱': TeamBio(powerUnitKo: '레드불 포드', championships: 6),
  '알핀': TeamBio(powerUnitKo: '메르세데스'),
  '레이싱 불스': TeamBio(powerUnitKo: '레드불 포드'),
  '하스': TeamBio(powerUnitKo: '페라리'),
  '윌리엄스': TeamBio(powerUnitKo: '메르세데스', championships: 9),
  '아우디': TeamBio(powerUnitKo: '아우디'),
  '애스턴 마틴': TeamBio(powerUnitKo: '혼다'),
  '캐딜락': TeamBio(powerUnitKo: '페라리'),
};

/// "2006년 8월 25일 (20세)" — 만 나이는 [now] 기준(KST 날짜 비교라 하루 오차 무시).
String formatBirthDateKo(String birthDate, DateTime now) {
  final date = DateTime.tryParse(birthDate);
  if (date == null) return birthDate;
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return '${date.year}년 ${date.month}월 ${date.day}일 ($age세)';
}
