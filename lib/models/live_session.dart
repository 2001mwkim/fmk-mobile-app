import 'package:flutter/material.dart';

import '../data/races.dart';
import '../theme/app_colors.dart';
import 'race.dart';
import 'race_session.dart';

// 드라이버 액센트 컬러는 data/drivers.dart 로 이동했지만, 기존 사용처가
// live_session.dart 를 통해 참조하므로 여기서 재노출한다.
export '../data/drivers.dart' show liveDriverAccent;

/// 웹 lib/live/types.ts 의 라이브 세션 타입을 Flutter로 옮긴 모델.
/// 실제 데이터(SignalR/live.json) 연결 전까지 UI 구조만 정의한다.
enum LiveSessionStatus { live, ended, inactive }

/// 웹 LiveDriverPosition 대응.
class LiveDriverPosition {
  const LiveDriverPosition({
    required this.position,
    required this.code,
    required this.displayName,
    this.racingNumber,
    this.gapToLeader,
    this.interval,
    this.lapTime,
    this.displayTime,
    this.lastLapTime,
    this.bestLapTime,
    this.personalBestLapTime,
    this.sector1,
    this.sector2,
    this.sector3,
    this.compound,
    this.tyreAge,
    this.stint,
    this.pitStops,
    this.inPit = false,
    this.retired = false,
    this.speedTrap,
    this.lastLapFlag,
    this.bestLapIsOverall = false,
    this.sectorDetails = const [],
    this.bestSectors = const [],
    this.speedI1,
    this.speedI2,
    this.stints = const [],
  });

  final int position;
  final String code;
  final String displayName;
  final String? racingNumber;
  final String? gapToLeader;
  final String? interval;
  final String? lapTime;
  final String? displayTime;
  final String? lastLapTime;
  final String? bestLapTime;
  final String? personalBestLapTime;
  final String? sector1;
  final String? sector2;
  final String? sector3;
  final String? compound;
  final int? tyreAge;
  final int? stint;
  final int? pitStops;
  final bool inPit;
  final bool retired;
  final String? speedTrap;

  // ── 라이브 보드 탭(LAP/SECTOR/TIRE) 상세 ──
  /// LAST 랩 색상 플래그: 'ob' 전체최고(퍼플) / 'pb' 개인최고(그린).
  final String? lastLapFlag;

  /// 개인 베스트 랩이 세션 전체 1위(퍼플 표시 대상)인지.
  final bool bestLapIsOverall;

  /// 섹터별 상세(값·플래그·미니섹터). 비어 있으면 sector1~3 로 폴백.
  final List<LiveSectorDetail> sectorDetails;

  /// 개인 베스트 섹터 타임(S1~S3 순서).
  final List<String?> bestSectors;

  /// 스피드트랩 1·2 구간 속도(km/h).
  final String? speedI1;
  final String? speedI2;

  /// 이 세션의 스틴트 히스토리(타이어 사용 순서).
  final List<LiveStint> stints;

  /// 갭 선택 규칙.
  /// race/sprint: interval 만 사용 — 컬럼 라벨이 'INTERVAL'인데 gapToLeader 로
  /// 폴백하면 행마다 숫자의 의미가 달라진다(없으면 '—').
  /// 그 외: gapToLeader 우선(현재 UI 미사용 경로).
  String gap({required bool raceLike}) {
    if (raceLike) return interval ?? '—';
    return gapToLeader ?? interval ?? '—';
  }

  /// UI에 표시할 시간. Race/Sprint는 기존 gap/interval, Practice/Qualifying은
  /// 현재 세션 랩타임(displayTime/lapTime)만 사용한다. 랩타임이 아직 없으면
  /// gap/interval로 대체하지 않고 '—'를 보여준다(이전 세션 gap 재사용 방지).
  String time({required bool raceLike}) {
    if (raceLike) return gap(raceLike: true);
    return displayTime ?? lapTime ?? '—';
  }
}

/// 섹터 하나의 라이브 보드 상세(값 + 최고기록 플래그 + 미니섹터).
class LiveSectorDetail {
  const LiveSectorDetail({this.value, this.flag, this.segments = const []});

  final String? value;

  /// 'ob' 전체최고(퍼플) / 'pb' 개인최고(그린) / null.
  final String? flag;

  /// 미니섹터 상태 코드: 2048 완주 / 2049 개인최고 / 2051 전체최고 / 2064 핏.
  final List<int> segments;
}

/// 이 세션의 스틴트 하나(타이어 컴파운드 + 사용 랩 수).
class LiveStint {
  const LiveStint({this.compound, this.laps});

  final String? compound;
  final int? laps;
}

/// 세션 텍스트(sessionType/sessionName)로 레이스류 여부 판정 — 스냅샷과
/// 직전 세션 결과가 같은 규칙을 공유한다.
bool liveTextIsRaceOrSprint(String? sessionType, String? sessionName) {
  final text = '${sessionType ?? ''} ${sessionName ?? ''}'.toLowerCase();
  if (text.contains('practice') ||
      text.contains('qualifying') ||
      text.contains('shootout') ||
      text.contains('프랙티스') ||
      text.contains('퀄리')) {
    return false;
  }
  return text.contains('race') ||
      text.contains('sprint') ||
      text.contains('레이스') ||
      text.contains('스프린트');
}

/// 가장 최근에 끝난 세션의 최종 순위(live.json 최상위 `lastSession`).
///
/// F1DB 공식 결과는 그랑프리 종료 후에나 발행되므로, 주말 중에는 이 데이터가
/// "직전 세션 결과"의 소스가 된다(collector 메모리 보관 — 재시작 시 소실).
class LiveLastSession {
  const LiveLastSession({
    this.raceId,
    this.raceName,
    this.sessionType,
    this.sessionName,
    this.endedAt,
    this.classification = const [],
  });

  final String? raceId;
  final String? raceName;
  final String? sessionType;
  final String? sessionName;
  final DateTime? endedAt;
  final List<LiveDriverPosition> classification;

  bool get isRaceOrSprint =>
      liveTextIsRaceOrSprint(sessionType, sessionName);

  /// 화면 표시용 한글 세션 이름.
  String get sessionTitleKo => liveSessionLabelKo(sessionName, sessionType);
}

class LiveWeather {
  const LiveWeather({
    this.airTemperature,
    this.trackTemperature,
    this.humidity,
    this.pressure,
    this.rainfall,
    this.windSpeed,
    this.windDirection,
  });

  final double? airTemperature;
  final double? trackTemperature;
  final double? humidity;
  final double? pressure;
  final bool? rainfall;
  final double? windSpeed;
  final int? windDirection;
}

class LiveRaceControlMessage {
  const LiveRaceControlMessage({
    required this.message,
    this.timestamp,
    this.category,
    this.flag,
    this.scope,
    this.racingNumber,
  });

  final String message;
  final DateTime? timestamp;
  final String? category;
  final String? flag;
  final String? scope;
  final String? racingNumber;
}

/// 웹 LiveSessionSnapshot 대응(표시에 필요한 필드만).
class LiveSessionSnapshot {
  const LiveSessionSnapshot({
    required this.status,
    required this.updatedAt,
    this.raceId,
    this.raceName,
    this.sessionKey,
    this.sessionType,
    this.sessionName,
    this.currentLap,
    this.totalLaps,
    this.topThree = const [],
    this.classification = const [],
    this.countryFlag,
    this.endedAt,
    this.visibleUntil,
    this.trackStatus,
    this.trackStatusMessage,
    this.remainingTime,
    this.clockStopped = false,
    this.weather,
    this.raceControlMessages = const [],
    this.lastSession,
  });

  final LiveSessionStatus status;

  /// 표시용 갱신 시각 문자열(예: '22:34'). 실데이터 연결 시 포맷터로 대체.
  final String updatedAt;
  final String? raceId;
  final String? raceName;

  /// collector가 내려주는 현재 세션 식별 키. classification의 랩타임이 현재
  /// 세션에서 생성된 값인지 검증(디버그)하는 용도.
  final String? sessionKey;
  final String? sessionType;
  final String? sessionName;
  final int? currentLap;
  final int? totalLaps;
  final List<LiveDriverPosition> topThree;
  final List<LiveDriverPosition> classification;
  final String? countryFlag;

  /// 세션이 종료된 시각(ISO). 웹 collector 의 snapshot.endedAt 대응.
  final DateTime? endedAt;

  /// 종료 후 최종 결과를 노출하는 마감 시각(endedAt + 30분). 웹 visibleUntil 대응.
  final DateTime? visibleUntil;
  final String? trackStatus;
  final String? trackStatusMessage;
  final String? remainingTime;

  /// 세션 시계 정지 여부(레드 플래그 등) — 남은 시간 로컬 티커가 이때 멈춘다.
  final bool clockStopped;
  final LiveWeather? weather;
  final List<LiveRaceControlMessage> raceControlMessages;

  /// 가장 최근에 끝난 세션의 최종 순위(컨트롤러가 스냅샷과 별개로 보존).
  final LiveLastSession? lastSession;

  bool get isEnded => status == LiveSessionStatus.ended;

  /// 종료됐지만 visibleUntil 이전이라 '최종 결과'로 노출 가능한 상태인가.
  /// visibleUntil 이 아직 없으면(필드 미제공) status 만으로 판단(노출 안 함).
  bool get isRecentlyEnded {
    if (status != LiveSessionStatus.ended) return false;
    final until = visibleUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// live 이거나 종료 후 30분 이내면 화면에 표시(웹 isDisplayableSnapshot 대응).
  bool get isDisplayable => status == LiveSessionStatus.live || isRecentlyEnded;

  /// practice/qualifying/shootout 이 아니고 race/sprint 면 true.
  /// 한글 세션명('레이스'/'스프린트'/'퀄리파잉'/'프랙티스')도 인식한다.
  bool get isRaceOrSprint =>
      liveTextIsRaceOrSprint(sessionType, sessionName);

  bool get showLap => isRaceOrSprint && currentLap != null && totalLaps != null;

  String get sessionTitle => sessionName ?? sessionType ?? 'Session';

  /// 화면 표시용 한글 세션 이름(영문 live.json 안전 변환).
  String get sessionTitleKo => liveSessionLabelKo(sessionName, sessionType);

  /// 갱신 시각을 KST 기준으로 표시(예: '업데이트 13:42 KST').
  /// updatedAt 이 ISO 면 KST(UTC+9)로 변환, 비어있으면 null(표시 생략),
  /// 파싱 불가하면 원문을 그대로 보여준다(웹 formatLiveUpdatedAt 의 안전 대체).
  String? get updatedAtLabel {
    if (updatedAt.isEmpty) return null;
    final parsed = DateTime.tryParse(updatedAt);
    if (parsed == null) return updatedAt;
    final kst = parsed.toUtc().add(const Duration(hours: 9));
    String two(int n) => n.toString().padLeft(2, '0');
    return '업데이트 ${two(kst.hour)}:${two(kst.minute)} KST';
  }

  String get summary {
    if (isRaceOrSprint && currentLap != null && totalLaps != null) {
      return 'Lap $currentLap / $totalLaps · 현재 Top 3';
    }
    return '세션 Top 3';
  }

  String get topThreeLabel => isEnded ? '최종 Top 3' : '현재 Top 3';

  String get classificationTitle {
    if (isEnded) {
      return isRaceOrSprint ? '최종 레이스 결과' : '최종 세션 순위';
    }
    return isRaceOrSprint ? '현재 레이스 순위' : '세션 순위';
  }

  // 연습/퀄리 표시값은 개인 베스트 우선(lapTime 선택 규칙)이라 'LAP'(방금 랩)
  // 으로 읽히면 오해 — 타이밍 보드 관례대로 'BEST'로 라벨링한다.
  String get gapColumnLabel => isRaceOrSprint ? 'INTERVAL' : 'BEST';
}

/// 퀄리파잉 세그먼트(Q1/Q2/Q3)를 sessionName/sessionType 에서 뽑아낸다.
///
/// collector 가 sessionName 에 세그먼트를 넣어주면(예: 'Qualifying 2', 'Q3',
/// 'Sprint Qualifying 1') 이를 'Q2'/'Q3'/'SQ1' 로 반환한다. 세그먼트 정보가
/// 없으면(현재의 'Qualifying' 처럼) null 을 돌려주고, 호출부는 세션 라벨로 대체한다.
/// 퀄리파잉 계열이 아니면(레이스/프랙티스) 항상 null.
String? liveQualifyingSegment(String? sessionName, String? sessionType) {
  final raw = '${sessionName ?? ''} ${sessionType ?? ''}'.trim();
  if (raw.isEmpty) return null;

  final lower = raw.toLowerCase();
  final isQualifying =
      lower.contains('qualifying') ||
      lower.contains('qualy') ||
      lower.contains('shootout') ||
      lower.contains('퀄리');
  if (!isQualifying) return null;

  final digit = RegExp(r'[123]').firstMatch(raw)?.group(0);
  if (digit == null) return null;

  final isSprint =
      lower.contains('sprint') ||
      lower.contains('스프린트') ||
      lower.contains('shootout');
  return isSprint ? 'SQ$digit' : 'Q$digit';
}

/// 스케줄을 반영한 라이브 박스 노출 여부.
///
/// - live: 항상 노출.
/// - ended: 같은 그랑프리 주말의 다음 세션 시작 30분 전까지(마지막 레이스는 종료
///   1시간 후까지) 결과를 계속 노출한다. 예) 레이스 날에도 직전 퀄리파잉 결과 유지.
///   endedAt 이 없으면(collector 가 세션 종료 후 재시작해 live 를 관측 못 한 경우)
///   앱 스케줄상의 세션 종료 시각으로 대체해 같은 규칙을 적용한다.
///   스케줄 매칭에 실패하면 기존 [LiveSessionSnapshot.isDisplayable](종료+30분) 규칙으로
///   안전하게 fallback 한다.
bool isLiveSnapshotDisplayable(LiveSessionSnapshot snapshot, [DateTime? now]) {
  if (isLiveSnapshotSessionActive(snapshot, now)) return true;
  if (snapshot.status != LiveSessionStatus.ended) return false;

  // 스케줄 폴백은 collector 가 lifecycle 정보를 아예 못 준 경우
  // (endedAt/visibleUntil 둘 다 없음)에만 적용한다. visibleUntil 이 명시돼
  // 있으면(만료 포함) collector 의 판단을 그대로 따른다.
  final endedAt =
      snapshot.endedAt ??
      (snapshot.visibleUntil == null
          ? scheduledLiveSessionEnd(snapshot)
          : null);
  final until = liveEndedResultVisibleUntil(
    raceId: snapshot.raceId,
    raceName: snapshot.raceName,
    endedAt: endedAt,
  );
  if (until == null) return snapshot.isDisplayable;
  return (now ?? DateTime.now()).isBefore(until);
}

/// 스냅샷 세션의 스케줄상 종료 시각.
///
/// collector 는 live 상태를 직접 관측한 세션에만 endedAt 을 기록한다. 세션 종료
/// 후 collector 를 재시작하면 ended 스냅샷에 endedAt 이 없어서, 그대로면
/// '다음 세션 30분 전까지 결과 유지' 규칙이 무력화되고 결과가 즉시 숨겨진다.
/// 이때 races.dart 스케줄에서 해당 세션의 종료 시각을 구해 endedAt 대용으로
/// 쓴다. 지난 주말의 stale 세션이면 이 시각 기준 노출 기한도 이미 지났으므로
/// 잘못 노출될 위험이 없다. 레이스/세션 매칭 실패 시 null.
DateTime? scheduledLiveSessionEnd(LiveSessionSnapshot snapshot) {
  final race = resolveLiveRace(snapshot.raceId, snapshot.raceName);
  if (race == null) return null;
  final session = liveRaceSessionForSnapshot(snapshot, race);
  if (session == null) return null;
  return getSessionEndDate(race, session);
}

/// collector 가 Q1/Q2 같은 하위 구간 종료를 `ended` 로 보내도, 앱의 스케줄상
/// 상위 세션(퀄리파잉/스프린트 퀄리파잉)이 아직 진행 중이면 LIVE 로 취급한다.
///
/// 이 보정은 세그먼트 사이 휴식이 존재하는 퀄리파잉 계열에만 적용한다.
/// 레이스/스프린트/프랙티스는 세그먼트가 없어서 collector 의 `ended` 가 곧
/// 실제 종료다 — 스케줄 창이 남았다고 LIVE 로 되돌리면, 일찍 끝난 레이스가
/// 스케줄상 종료 시각까지 계속 LIVE 로 표시되는 문제가 생긴다.
bool isLiveSnapshotSessionActive(
  LiveSessionSnapshot snapshot, [
  DateTime? now,
]) {
  if (snapshot.status == LiveSessionStatus.live) return true;
  if (snapshot.status != LiveSessionStatus.ended) return false;

  final race = resolveLiveRace(snapshot.raceId, snapshot.raceName);
  final session = liveRaceSessionForSnapshot(snapshot, race);
  if (race == null || session == null) return false;
  if (session.id != 'qualifying' && session.id != 'sprint_qualifying') {
    return false;
  }

  final currentTime = now ?? DateTime.now();
  final start = getSessionDate(race, session);
  final end = getSessionEndDate(race, session);
  return !currentTime.isBefore(start) && currentTime.isBefore(end);
}

/// 스냅샷이 [race]의 레이스 세션이 실제로 끝났음을 알려주는지.
///
/// 레이스가 스케줄상 종료 창(시작+2시간)보다 일찍 끝나면, 라이브 데이터를
/// 근거로 홈 화면이 스케줄 폴백('진행중')을 무시하고 다음 그랑프리로
/// 넘어갈 수 있게 한다.
bool liveSnapshotMarksRaceEnded(
  LiveSessionSnapshot snapshot,
  Race race, [
  DateTime? now,
]) {
  if (snapshot.status != LiveSessionStatus.ended) return false;
  if (isLiveSnapshotSessionActive(snapshot, now)) return false;

  final snapshotRace = resolveLiveRace(snapshot.raceId, snapshot.raceName);
  if (snapshotRace == null || snapshotRace.id != race.id) return false;

  final session = liveRaceSessionForSnapshot(snapshot, snapshotRace);
  return session?.id == 'race';
}

RaceSession? liveRaceSessionForSnapshot(
  LiveSessionSnapshot snapshot, [
  Race? resolvedRace,
]) {
  final race =
      resolvedRace ?? resolveLiveRace(snapshot.raceId, snapshot.raceName);
  if (race == null) return null;

  final text = '${snapshot.sessionType ?? ''} ${snapshot.sessionName ?? ''}'
      .toLowerCase();

  String? sessionId;
  if (text.contains('practice 1') ||
      text.contains('free practice 1') ||
      text.contains('fp1') ||
      text.contains('프랙티스 1')) {
    sessionId = 'fp1';
  } else if (text.contains('practice 2') ||
      text.contains('free practice 2') ||
      text.contains('fp2') ||
      text.contains('프랙티스 2')) {
    sessionId = 'fp2';
  } else if (text.contains('practice 3') ||
      text.contains('free practice 3') ||
      text.contains('fp3') ||
      text.contains('프랙티스 3')) {
    sessionId = 'fp3';
  } else if ((text.contains('sprint') || text.contains('스프린트')) &&
      (text.contains('qualifying') ||
          text.contains('shootout') ||
          text.contains('퀄리'))) {
    sessionId = 'sprint_qualifying';
  } else if (text.contains('sprint') || text.contains('스프린트')) {
    sessionId = 'sprint';
  } else if (text.contains('qualifying') || text.contains('퀄리')) {
    sessionId = 'qualifying';
  } else if (text.contains('race') || text.contains('레이스')) {
    sessionId = 'race';
  }

  if (sessionId == null) return null;
  for (final session in race.sessions) {
    if (session.id == sessionId) return session;
  }
  return null;
}

/// 종료 후 노출 라벨(웹 LIVE_ENDED_HOME_LABEL / LIVE_ENDED_PANEL_LABEL).
const String liveEndedHomeLabel = 'LIVE 종료 · 최종 결과';
const String liveEndedPanelLabel = '세션 종료 · 최종 결과';

/// 라이브 세션 이름(영문 live.json)을 한글 표기로 변환한다.
///
/// 실데이터의 [sessionName]/[sessionType] 은 'Race', 'Qualifying', 'Practice 1',
/// 'Sprint', 'Sprint Qualifying' 처럼 영어로 들어올 수 있다. 알 수 없는 값이나
/// 이미 한글인 값은 원문을 그대로 돌려준다(안전한 fallback).
String liveSessionLabelKo(String? sessionName, String? sessionType) {
  final named = sessionName?.trim() ?? '';
  final raw = named.isNotEmpty ? named : (sessionType?.trim() ?? '');
  if (raw.isEmpty) return '세션';

  final lower = raw.toLowerCase();
  final isSprint = lower.contains('sprint');
  final isQualifying =
      lower.contains('qualifying') ||
      lower.contains('qualy') ||
      lower.contains('shootout');

  if (isSprint && isQualifying) return '스프린트 퀄리파잉';
  if (isSprint) return '스프린트';
  if (isQualifying) return '퀄리파잉';

  if (lower.contains('practice') || RegExp(r'\bfp\s*\d').hasMatch(lower)) {
    final number = RegExp(r'\d').firstMatch(raw)?.group(0);
    return number == null ? '프랙티스' : '프리 프랙티스 $number';
  }

  if (lower.contains('race')) return '레이스';

  // 이미 한글이거나 매핑되지 않는 값은 원문 유지.
  return raw;
}

/// 포디움(1~3위) 배지 색. 웹은 1위에 노란색을 쓰지만 앱 규칙상 레드로 대체.
({Color background, Color foreground}) livePodiumColors(int position) {
  switch (position) {
    case 1:
      return (
        background: const Color(0x26EF4444), // red-500/15
        foreground: const Color(0xFFF87171), // red-400
      );
    case 2:
      return (
        background: const Color(0x2694A3B8), // slate-400/15
        foreground: const Color(0xFFCBD5E1), // slate-300
      );
    case 3:
      return (
        background: const Color(0x26F97316), // orange-500/15
        foreground: const Color(0xFFFB923C), // orange-400
      );
    default:
      return (
        background: AppColors.rowBorder, // white/5
        foreground: AppColors.muted,
      );
  }
}
