import '../models/live_session.dart';

/// 미리보기용 mock 스냅샷 (웹 lib/live/mockSnapshot.ts 대응).
/// 실제 라이브 데이터 연결 전, 라이브 UI 시각 확인용으로만 쓴다.
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

/// 라이브 UI 미리보기 토글. 실데이터 연동 전에는 false 라서 화면에 노출되지 않는다.
/// 실제 라이브 데이터(SignalR/live.json) 연결 시 [getLiveSession] 만 교체하면 된다.
bool livePreviewEnabled = false;

/// 현재 라이브 스냅샷. 실데이터 연결 전에는 null(미표시).
LiveSessionSnapshot? getLiveSnapshot() =>
    livePreviewEnabled ? mockLiveSession : null;
