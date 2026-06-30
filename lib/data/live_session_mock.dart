import '../models/live_session.dart';

/// 미리보기/테스트용 mock 스냅샷 (웹 lib/live/mockSnapshot.ts 대응).
/// 실제 라이브 데이터는 LiveSessionController/LiveSessionService(live.json)가 공급한다.
/// 이 값은 라이브 위젯의 시각 확인 및 위젯 테스트에서만 사용한다.
final LiveSessionSnapshot mockLiveSession = LiveSessionSnapshot(
  status: LiveSessionStatus.live,
  updatedAt: '2026-06-30T04:34:00.000Z', // KST 13:34
  raceId: 'spain',
  raceName: '스페인 그랑프리',
  sessionType: 'race',
  sessionName: '레이스',
  currentLap: 42,
  totalLaps: 66,
  topThree: const [
    LiveDriverPosition(
      position: 1,
      code: 'NOR',
      displayName: '랜도 노리스',
      racingNumber: '4',
    ),
    LiveDriverPosition(
      position: 2,
      code: 'PIA',
      displayName: '오스카 피아스트리',
      racingNumber: '81',
      interval: '+2.341',
    ),
    LiveDriverPosition(
      position: 3,
      code: 'LEC',
      displayName: '샤를 르클레르',
      racingNumber: '16',
      interval: '+5.118',
    ),
  ],
  classification: const [
    LiveDriverPosition(
      position: 1,
      code: 'NOR',
      displayName: '랜도 노리스',
      racingNumber: '4',
    ),
    LiveDriverPosition(
      position: 2,
      code: 'PIA',
      displayName: '오스카 피아스트리',
      racingNumber: '81',
      interval: '+2.341',
    ),
    LiveDriverPosition(
      position: 3,
      code: 'LEC',
      displayName: '샤를 르클레르',
      racingNumber: '16',
      interval: '+5.118',
    ),
    LiveDriverPosition(
      position: 4,
      code: 'VER',
      displayName: '막스 베르스타펜',
      racingNumber: '1',
      interval: '+8.402',
    ),
    LiveDriverPosition(
      position: 5,
      code: 'RUS',
      displayName: '조지 러셀',
      racingNumber: '63',
      interval: '+12.067',
    ),
    LiveDriverPosition(
      position: 6,
      code: 'HAM',
      displayName: '루이스 해밀턴',
      racingNumber: '44',
      interval: '+15.339',
    ),
  ],
);
