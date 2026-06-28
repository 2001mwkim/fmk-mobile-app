import '../models/race.dart';
import '../models/race_session.dart';

const String _kstOffset = '+09:00';
const Duration _defaultSessionDuration = Duration(minutes: 60);
const Map<String, Duration> _sessionDurations = {
  'sprint': Duration(minutes: 60),
  'race': Duration(minutes: 180),
};

const List<Race> races = [
  Race(
    id: 'australia-2026',
    round: 1,
    nameKo: '호주 그랑프리',
    nameEn: 'Australian Grand Prix',
    countryKo: '호주',
    cityKo: '멜버른',
    circuitKo: '앨버트 파크 서킷',
    startDate: '2026-03-06',
    endDate: '2026-03-08',
    hasSprint: false,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '3.6 금',
        time: '10:30',
        fullDateTime: '3월 6일 금요일 10:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '3.6 금',
        time: '14:00',
        fullDateTime: '3월 6일 금요일 14:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '3.7 토',
        time: '10:30',
        fullDateTime: '3월 7일 토요일 10:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '3.7 토',
        time: '14:00',
        fullDateTime: '3월 7일 토요일 14:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '3.8 일',
        time: '13:00',
        fullDateTime: '3월 8일 일요일 13:00',
      ),
    ],
  ),
  Race(
    id: 'china-2026',
    round: 2,
    nameKo: '중국 그랑프리',
    nameEn: 'Chinese Grand Prix',
    countryKo: '중국',
    cityKo: '상하이',
    circuitKo: '상하이 인터내셔널 서킷',
    startDate: '2026-03-13',
    endDate: '2026-03-15',
    hasSprint: true,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '3.13 금',
        time: '12:30',
        fullDateTime: '3월 13일 금요일 12:30',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '3.13 금',
        time: '16:30',
        fullDateTime: '3월 13일 금요일 16:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '3.14 토',
        time: '12:00',
        fullDateTime: '3월 14일 토요일 12:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '3.14 토',
        time: '16:00',
        fullDateTime: '3월 14일 토요일 16:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '3.15 일',
        time: '16:00',
        fullDateTime: '3월 15일 일요일 16:00',
      ),
    ],
  ),
  Race(
    id: 'japan-2026',
    round: 3,
    nameKo: '일본 그랑프리',
    nameEn: 'Japanese Grand Prix',
    countryKo: '일본',
    cityKo: '스즈카',
    circuitKo: '스즈카 서킷',
    startDate: '2026-03-27',
    endDate: '2026-03-29',
    hasSprint: false,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '3.27 금',
        time: '11:30',
        fullDateTime: '3월 27일 금요일 11:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '3.27 금',
        time: '15:00',
        fullDateTime: '3월 27일 금요일 15:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '3.28 토',
        time: '11:30',
        fullDateTime: '3월 28일 토요일 11:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '3.28 토',
        time: '15:00',
        fullDateTime: '3월 28일 토요일 15:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '3.29 일',
        time: '14:00',
        fullDateTime: '3월 29일 일요일 14:00',
      ),
    ],
  ),
  Race(
    id: 'bahrain',
    round: 4,
    nameKo: '바레인 그랑프리',
    nameEn: 'Bahrain Grand Prix',
    countryKo: '바레인',
    cityKo: '사키르',
    circuitKo: '바레인 인터내셔널 서킷',
    startDate: '2026-04-10',
    endDate: '2026-04-12',
    hasSprint: false,
    status: '종료',
    isCancelled: true,
    cancelNote: '해당 그랑프리는 2026 시즌 캘린더에서 취소되었습니다.',
    sessions: [],
  ),
  Race(
    id: 'saudi-arabia',
    round: 5,
    nameKo: '사우디아라비아 그랑프리',
    nameEn: 'Saudi Arabian Grand Prix',
    countryKo: '사우디아라비아',
    cityKo: '제다',
    circuitKo: '제다 코니시 서킷',
    startDate: '2026-04-17',
    endDate: '2026-04-19',
    hasSprint: false,
    status: '종료',
    isCancelled: true,
    cancelNote: '해당 그랑프리는 2026 시즌 캘린더에서 취소되었습니다.',
    sessions: [],
  ),
  Race(
    id: 'miami-2026',
    round: 6,
    nameKo: '마이애미 그랑프리',
    nameEn: 'Miami Grand Prix',
    countryKo: '미국',
    cityKo: '마이애미',
    circuitKo: '마이애미 인터내셔널 오토드롬',
    startDate: '2026-05-01',
    endDate: '2026-05-03',
    hasSprint: true,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '5.2 토',
        time: '01:00',
        fullDateTime: '5월 2일 토요일 01:00',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '5.2 토',
        time: '05:30',
        fullDateTime: '5월 2일 토요일 05:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '5.3 일',
        time: '01:00',
        fullDateTime: '5월 3일 일요일 01:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '5.3 일',
        time: '05:00',
        fullDateTime: '5월 3일 일요일 05:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '5.4 월',
        time: '02:00',
        fullDateTime: '5월 4일 월요일 02:00',
      ),
    ],
  ),
  Race(
    id: 'canada-2026',
    round: 7,
    nameKo: '캐나다 그랑프리',
    nameEn: 'Canadian Grand Prix',
    countryKo: '캐나다',
    cityKo: '몬트리올',
    circuitKo: '질 빌르너브 서킷',
    startDate: '2026-05-22',
    endDate: '2026-05-24',
    hasSprint: true,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '5.23 토',
        time: '01:30',
        fullDateTime: '5월 23일 토요일 01:30',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '5.23 토',
        time: '05:30',
        fullDateTime: '5월 23일 토요일 05:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '5.24 일',
        time: '01:00',
        fullDateTime: '5월 24일 일요일 01:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '5.24 일',
        time: '05:00',
        fullDateTime: '5월 24일 일요일 05:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '5.25 월',
        time: '05:00',
        fullDateTime: '5월 25일 월요일 05:00',
      ),
    ],
  ),
  Race(
    id: 'monaco-2026',
    round: 8,
    nameKo: '모나코 그랑프리',
    nameEn: 'Monaco Grand Prix',
    countryKo: '모나코',
    cityKo: '몬테카를로',
    circuitKo: '모나코 서킷',
    startDate: '2026-06-05',
    endDate: '2026-06-07',
    hasSprint: false,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '6.5 금',
        time: '20:30',
        fullDateTime: '6월 5일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '6.6 토',
        time: '00:00',
        fullDateTime: '6월 6일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '6.6 토',
        time: '19:30',
        fullDateTime: '6월 6일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '6.6 토',
        time: '23:00',
        fullDateTime: '6월 6일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '6.7 일',
        time: '22:00',
        fullDateTime: '6월 7일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'barcelona-catalunya-2026',
    round: 9,
    nameKo: '바르셀로나-카탈루냐 그랑프리',
    nameEn: 'Barcelona-Catalunya Grand Prix',
    countryKo: '스페인',
    cityKo: '바르셀로나',
    circuitKo: '바르셀로나-카탈루냐 서킷',
    startDate: '2026-06-12',
    endDate: '2026-06-14',
    hasSprint: false,
    status: '종료',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '6.12 금',
        time: '20:30',
        fullDateTime: '6월 12일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '6.13 토',
        time: '00:00',
        fullDateTime: '6월 13일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '6.13 토',
        time: '19:30',
        fullDateTime: '6월 13일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '6.13 토',
        time: '23:00',
        fullDateTime: '6월 13일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '6.14 일',
        time: '22:00',
        fullDateTime: '6월 14일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'austria-2026',
    round: 10,
    nameKo: '오스트리아 그랑프리',
    nameEn: 'Austrian Grand Prix',
    countryKo: '오스트리아',
    cityKo: '스필버그',
    circuitKo: '레드불 링',
    startDate: '2026-06-26',
    endDate: '2026-06-28',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '6.26 금',
        time: '20:30',
        fullDateTime: '6월 26일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '6.27 토',
        time: '00:00',
        fullDateTime: '6월 27일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '6.27 토',
        time: '19:30',
        fullDateTime: '6월 27일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '6.27 토',
        time: '23:00',
        fullDateTime: '6월 27일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '6.28 일',
        time: '22:00',
        fullDateTime: '6월 28일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'great-britain-2026',
    round: 11,
    nameKo: '영국 그랑프리',
    nameEn: 'British Grand Prix',
    countryKo: '영국',
    cityKo: '실버스톤',
    circuitKo: '실버스톤 서킷',
    startDate: '2026-07-03',
    endDate: '2026-07-05',
    hasSprint: true,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '7.3 금',
        time: '20:30',
        fullDateTime: '7월 3일 금요일 20:30',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '7.4 토',
        time: '00:30',
        fullDateTime: '7월 4일 토요일 00:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '7.4 토',
        time: '20:00',
        fullDateTime: '7월 4일 토요일 20:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '7.5 일',
        time: '00:00',
        fullDateTime: '7월 5일 일요일 00:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '7.5 일',
        time: '23:00',
        fullDateTime: '7월 5일 일요일 23:00',
      ),
    ],
  ),
  Race(
    id: 'belgium-2026',
    round: 12,
    nameKo: '벨기에 그랑프리',
    nameEn: 'Belgian Grand Prix',
    countryKo: '벨기에',
    cityKo: '스파',
    circuitKo: '스파-프랑코샹 서킷',
    startDate: '2026-07-17',
    endDate: '2026-07-19',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '7.17 금',
        time: '20:30',
        fullDateTime: '7월 17일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '7.18 토',
        time: '00:00',
        fullDateTime: '7월 18일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '7.18 토',
        time: '19:30',
        fullDateTime: '7월 18일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '7.18 토',
        time: '23:00',
        fullDateTime: '7월 18일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '7.19 일',
        time: '22:00',
        fullDateTime: '7월 19일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'hungary-2026',
    round: 13,
    nameKo: '헝가리 그랑프리',
    nameEn: 'Hungarian Grand Prix',
    countryKo: '헝가리',
    cityKo: '부다페스트',
    circuitKo: '헝가로링',
    startDate: '2026-07-24',
    endDate: '2026-07-26',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '7.24 금',
        time: '20:30',
        fullDateTime: '7월 24일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '7.25 토',
        time: '00:00',
        fullDateTime: '7월 25일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '7.25 토',
        time: '19:30',
        fullDateTime: '7월 25일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '7.25 토',
        time: '23:00',
        fullDateTime: '7월 25일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '7.26 일',
        time: '22:00',
        fullDateTime: '7월 26일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'netherlands-2026',
    round: 14,
    nameKo: '네덜란드 그랑프리',
    nameEn: 'Dutch Grand Prix',
    countryKo: '네덜란드',
    cityKo: '잔드보르트',
    circuitKo: '잔드보르트 서킷',
    startDate: '2026-08-21',
    endDate: '2026-08-23',
    hasSprint: true,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '8.21 금',
        time: '19:30',
        fullDateTime: '8월 21일 금요일 19:30',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '8.21 금',
        time: '23:30',
        fullDateTime: '8월 21일 금요일 23:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '8.22 토',
        time: '19:00',
        fullDateTime: '8월 22일 토요일 19:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '8.22 토',
        time: '23:00',
        fullDateTime: '8월 22일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '8.23 일',
        time: '22:00',
        fullDateTime: '8월 23일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'italy-2026',
    round: 15,
    nameKo: '이탈리아 그랑프리',
    nameEn: 'Italian Grand Prix',
    countryKo: '이탈리아',
    cityKo: '몬차',
    circuitKo: '몬차 국립 자동차 경주장',
    startDate: '2026-09-04',
    endDate: '2026-09-06',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '9.4 금',
        time: '19:30',
        fullDateTime: '9월 4일 금요일 19:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '9.4 금',
        time: '23:00',
        fullDateTime: '9월 4일 금요일 23:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '9.5 토',
        time: '19:30',
        fullDateTime: '9월 5일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '9.5 토',
        time: '23:00',
        fullDateTime: '9월 5일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '9.6 일',
        time: '22:00',
        fullDateTime: '9월 6일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'spain-2026',
    round: 16,
    nameKo: '스페인 그랑프리',
    nameEn: 'Spanish Grand Prix',
    countryKo: '스페인',
    cityKo: '마드리드',
    circuitKo: '마드리드 스트리트 서킷',
    startDate: '2026-09-11',
    endDate: '2026-09-13',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '9.11 금',
        time: '20:30',
        fullDateTime: '9월 11일 금요일 20:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '9.12 토',
        time: '00:00',
        fullDateTime: '9월 12일 토요일 00:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '9.12 토',
        time: '19:30',
        fullDateTime: '9월 12일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '9.12 토',
        time: '23:00',
        fullDateTime: '9월 12일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '9.13 일',
        time: '22:00',
        fullDateTime: '9월 13일 일요일 22:00',
      ),
    ],
  ),
  Race(
    id: 'azerbaijan-2026',
    round: 17,
    nameKo: '아제르바이잔 그랑프리',
    nameEn: 'Azerbaijan Grand Prix',
    countryKo: '아제르바이잔',
    cityKo: '바쿠',
    circuitKo: '바쿠 시티 서킷',
    startDate: '2026-09-24',
    endDate: '2026-09-26',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '9.24 목',
        time: '17:30',
        fullDateTime: '9월 24일 목요일 17:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '9.24 목',
        time: '21:00',
        fullDateTime: '9월 24일 목요일 21:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '9.25 금',
        time: '17:30',
        fullDateTime: '9월 25일 금요일 17:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '9.25 금',
        time: '21:00',
        fullDateTime: '9월 25일 금요일 21:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '9.26 토',
        time: '20:00',
        fullDateTime: '9월 26일 토요일 20:00',
      ),
    ],
  ),
  Race(
    id: 'singapore-2026',
    round: 18,
    nameKo: '싱가포르 그랑프리',
    nameEn: 'Singapore Grand Prix',
    countryKo: '싱가포르',
    cityKo: '싱가포르',
    circuitKo: '마리나 베이 스트리트 서킷',
    startDate: '2026-10-09',
    endDate: '2026-10-11',
    hasSprint: true,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '10.9 금',
        time: '17:30',
        fullDateTime: '10월 9일 금요일 17:30',
      ),
      RaceSession(
        id: 'sprint_qualifying',
        label: '스프린트 퀄리파잉',
        fullLabel: '스프린트 퀄리파잉',
        date: '10.9 금',
        time: '21:30',
        fullDateTime: '10월 9일 금요일 21:30',
      ),
      RaceSession(
        id: 'sprint',
        label: '스프린트',
        fullLabel: '스프린트',
        date: '10.10 토',
        time: '18:00',
        fullDateTime: '10월 10일 토요일 18:00',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '10.10 토',
        time: '22:00',
        fullDateTime: '10월 10일 토요일 22:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '10.11 일',
        time: '21:00',
        fullDateTime: '10월 11일 일요일 21:00',
      ),
    ],
  ),
  Race(
    id: 'united-states-2026',
    round: 19,
    nameKo: '미국 그랑프리',
    nameEn: 'United States Grand Prix',
    countryKo: '미국',
    cityKo: '오스틴',
    circuitKo: '서킷 오브 디 아메리카스',
    startDate: '2026-10-23',
    endDate: '2026-10-25',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '10.24 토',
        time: '02:30',
        fullDateTime: '10월 24일 토요일 02:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '10.24 토',
        time: '06:00',
        fullDateTime: '10월 24일 토요일 06:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '10.25 일',
        time: '02:30',
        fullDateTime: '10월 25일 일요일 02:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '10.25 일',
        time: '06:00',
        fullDateTime: '10월 25일 일요일 06:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '10.26 월',
        time: '05:00',
        fullDateTime: '10월 26일 월요일 05:00',
      ),
    ],
  ),
  Race(
    id: 'mexico-2026',
    round: 20,
    nameKo: '멕시코시티 그랑프리',
    nameEn: 'Mexico City Grand Prix',
    countryKo: '멕시코',
    cityKo: '멕시코시티',
    circuitKo: '에르마노스 로드리게스 자동차 경주장',
    startDate: '2026-10-30',
    endDate: '2026-11-01',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '10.31 토',
        time: '03:30',
        fullDateTime: '10월 31일 토요일 03:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '10.31 토',
        time: '07:00',
        fullDateTime: '10월 31일 토요일 07:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '11.1 일',
        time: '02:30',
        fullDateTime: '11월 1일 일요일 02:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '11.1 일',
        time: '06:00',
        fullDateTime: '11월 1일 일요일 06:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '11.2 월',
        time: '05:00',
        fullDateTime: '11월 2일 월요일 05:00',
      ),
    ],
  ),
  Race(
    id: 'brazil-2026',
    round: 21,
    nameKo: '상파울루 그랑프리',
    nameEn: 'São Paulo Grand Prix',
    countryKo: '브라질',
    cityKo: '상파울루',
    circuitKo: '인터라고스 서킷',
    startDate: '2026-11-06',
    endDate: '2026-11-08',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '11.7 토',
        time: '00:30',
        fullDateTime: '11월 7일 토요일 00:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '11.7 토',
        time: '04:00',
        fullDateTime: '11월 7일 토요일 04:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '11.7 토',
        time: '23:30',
        fullDateTime: '11월 7일 토요일 23:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '11.8 일',
        time: '03:00',
        fullDateTime: '11월 8일 일요일 03:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '11.9 월',
        time: '02:00',
        fullDateTime: '11월 9일 월요일 02:00',
      ),
    ],
  ),
  Race(
    id: 'las-vegas-2026',
    round: 22,
    nameKo: '라스베이거스 그랑프리',
    nameEn: 'Las Vegas Grand Prix',
    countryKo: '미국',
    cityKo: '라스베이거스',
    circuitKo: '라스베이거스 스트립 서킷',
    startDate: '2026-11-19',
    endDate: '2026-11-21',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '11.20 금',
        time: '09:30',
        fullDateTime: '11월 20일 금요일 09:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '11.20 금',
        time: '13:00',
        fullDateTime: '11월 20일 금요일 13:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '11.21 토',
        time: '09:30',
        fullDateTime: '11월 21일 토요일 09:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '11.21 토',
        time: '13:00',
        fullDateTime: '11월 21일 토요일 13:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '11.22 일',
        time: '13:00',
        fullDateTime: '11월 22일 일요일 13:00',
      ),
    ],
  ),
  Race(
    id: 'qatar-2026',
    round: 23,
    nameKo: '카타르 그랑프리',
    nameEn: 'Qatar Grand Prix',
    countryKo: '카타르',
    cityKo: '루사일',
    circuitKo: '루사일 인터내셔널 서킷',
    startDate: '2026-11-27',
    endDate: '2026-11-29',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '11.27 금',
        time: '22:30',
        fullDateTime: '11월 27일 금요일 22:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '11.28 토',
        time: '02:00',
        fullDateTime: '11월 28일 토요일 02:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '11.28 토',
        time: '23:30',
        fullDateTime: '11월 28일 토요일 23:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '11.29 일',
        time: '03:00',
        fullDateTime: '11월 29일 일요일 03:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '11.30 월',
        time: '01:00',
        fullDateTime: '11월 30일 월요일 01:00',
      ),
    ],
  ),
  Race(
    id: 'abu-dhabi-2026',
    round: 24,
    nameKo: '아부다비 그랑프리',
    nameEn: 'Abu Dhabi Grand Prix',
    countryKo: '아랍에미리트',
    cityKo: '아부다비',
    circuitKo: '야스 마리나 서킷',
    startDate: '2026-12-04',
    endDate: '2026-12-06',
    hasSprint: false,
    status: '예정',

    sessions: [
      RaceSession(
        id: 'fp1',
        label: 'FP1',
        fullLabel: '프리 프랙티스 1',
        date: '12.4 금',
        time: '18:30',
        fullDateTime: '12월 4일 금요일 18:30',
      ),
      RaceSession(
        id: 'fp2',
        label: 'FP2',
        fullLabel: '프리 프랙티스 2',
        date: '12.4 금',
        time: '22:00',
        fullDateTime: '12월 4일 금요일 22:00',
      ),
      RaceSession(
        id: 'fp3',
        label: 'FP3',
        fullLabel: '프리 프랙티스 3',
        date: '12.5 토',
        time: '19:30',
        fullDateTime: '12월 5일 토요일 19:30',
      ),
      RaceSession(
        id: 'qualifying',
        label: '퀄리파잉',
        fullLabel: '퀄리파잉',
        date: '12.5 토',
        time: '23:00',
        fullDateTime: '12월 5일 토요일 23:00',
      ),
      RaceSession(
        id: 'race',
        label: '레이스',
        fullLabel: '레이스',
        date: '12.6 일',
        time: '22:00',
        fullDateTime: '12월 6일 일요일 22:00',
      ),
    ],
  ),
];

DateTime getSessionDate(Race race, RaceSession session) {
  final monthDay = session.date.split(' ').first;
  final parts = monthDay.split('.');
  final year = int.parse(race.startDate.substring(0, 4));
  final month = int.parse(parts[0]).toString().padLeft(2, '0');
  final day = int.parse(parts[1]).toString().padLeft(2, '0');

  return DateTime.parse('$year-$month-${day}T${session.time}:00$_kstOffset');
}

DateTime getSessionEndDate(Race race, RaceSession session) {
  final duration = _sessionDurations[session.id] ?? _defaultSessionDuration;
  return getSessionDate(race, session).add(duration);
}

SessionStatus getSessionStatus(
  Race race,
  RaceSession session, [
  DateTime? now,
]) {
  if (race.isCancelled) return SessionStatus.ended;

  final currentTime = now ?? DateTime.now();
  final sessionStart = getSessionDate(race, session);
  if (currentTime.isBefore(sessionStart)) return SessionStatus.upcoming;

  return currentTime.isBefore(getSessionEndDate(race, session))
      ? SessionStatus.live
      : SessionStatus.ended;
}

RaceSession? getLiveSession(Race race, [DateTime? now]) {
  if (race.isCancelled) return null;

  for (final session in race.sessions) {
    if (getSessionStatus(race, session, now) == SessionStatus.live) {
      return session;
    }
  }

  return null;
}

DateTime? getRaceWeekendStartDate(Race race) {
  if (race.sessions.isEmpty) return null;

  DateTime? earliest;
  for (final session in race.sessions) {
    final sessionStart = getSessionDate(race, session);
    if (earliest == null || sessionStart.isBefore(earliest)) {
      earliest = sessionStart;
    }
  }

  return earliest;
}

DateTime? getRaceWeekendEndDate(Race race) {
  if (race.sessions.isEmpty) return null;

  for (final session in race.sessions) {
    if (session.id == 'race') return getSessionEndDate(race, session);
  }

  DateTime? latest;
  for (final session in race.sessions) {
    final sessionEnd = getSessionEndDate(race, session);
    if (latest == null || sessionEnd.isAfter(latest)) {
      latest = sessionEnd;
    }
  }

  return latest;
}

String getRaceStatus(Race race, [DateTime? now]) {
  if (race.isCancelled) return RaceStatus.ended;

  final weekendStart = getRaceWeekendStartDate(race);
  final weekendEnd = getRaceWeekendEndDate(race);
  if (weekendStart == null || weekendEnd == null) return race.status;

  final currentTime = now ?? DateTime.now();
  if (currentTime.isBefore(weekendStart)) return RaceStatus.scheduled;

  return currentTime.isBefore(weekendEnd)
      ? RaceStatus.inProgress
      : RaceStatus.ended;
}

String getRaceDisplayStatus(Race race, [DateTime? now]) {
  return race.isCancelled ? RaceStatus.cancelled : getRaceStatus(race, now);
}

Race getNextRace([DateTime? now]) {
  final currentTime = now ?? DateTime.now();

  for (final race in races) {
    if (race.isCancelled) continue;

    final raceSession = _getRaceSession(race);
    if (raceSession != null &&
        getSessionEndDate(race, raceSession).isAfter(currentTime)) {
      return race;
    }
  }

  return races.last;
}

RaceSession? getNextSession(Race race, [DateTime? now]) {
  if (race.sessions.isEmpty) return null;

  final currentTime = now ?? DateTime.now();
  final liveSession = getLiveSession(race, currentTime);
  if (liveSession != null) return liveSession;

  for (final session in race.sessions) {
    if (!getSessionDate(race, session).isBefore(currentTime)) {
      return session;
    }
  }

  return race.sessions.last;
}

int getDaysUntilRace(Race race, [DateTime? now]) {
  final raceStart = _getRaceStart(race);
  if (raceStart == null) return 0;

  final raceDate = _kstDateOnly(raceStart);
  final today = _kstDateOnly(now ?? DateTime.now());

  return raceDate.difference(today).inDays;
}

RaceSession? _getRaceSession(Race race) {
  for (final session in race.sessions) {
    if (session.id == 'race') return session;
  }

  return null;
}

DateTime? _getRaceStart(Race race) {
  final raceSession = _getRaceSession(race);
  return raceSession == null ? null : getSessionDate(race, raceSession);
}

DateTime _kstDateOnly(DateTime date) {
  final kstDate = date.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(kstDate.year, kstDate.month, kstDate.day);
}
