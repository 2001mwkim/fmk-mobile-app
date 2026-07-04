import 'package:flutter/material.dart';

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
  });

  final int position;
  final String code;
  final String displayName;
  final String? racingNumber;
  final String? gapToLeader;
  final String? interval;

  /// 웹과 동일한 갭 선택 규칙.
  /// race/sprint: interval 우선, 그 외: gapToLeader 우선. 둘 다 없으면 '—'.
  String gap({required bool raceLike}) {
    if (raceLike) return interval ?? gapToLeader ?? '—';
    return gapToLeader ?? interval ?? '—';
  }
}

/// 웹 LiveSessionSnapshot 대응(표시에 필요한 필드만).
class LiveSessionSnapshot {
  const LiveSessionSnapshot({
    required this.status,
    required this.updatedAt,
    this.raceId,
    this.raceName,
    this.sessionType,
    this.sessionName,
    this.currentLap,
    this.totalLaps,
    this.topThree = const [],
    this.classification = const [],
    this.countryFlag,
    this.endedAt,
    this.visibleUntil,
  });

  final LiveSessionStatus status;

  /// 표시용 갱신 시각 문자열(예: '22:34'). 실데이터 연결 시 포맷터로 대체.
  final String updatedAt;
  final String? raceId;
  final String? raceName;
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
  bool get isRaceOrSprint {
    final text = '${sessionType ?? ''} ${sessionName ?? ''}'.toLowerCase();
    if (text.contains('practice') ||
        text.contains('qualifying') ||
        text.contains('shootout')) {
      return false;
    }
    return text.contains('race') || text.contains('sprint');
  }

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

  String get gapColumnLabel => isRaceOrSprint ? 'INTERVAL' : 'GAP';
}

/// 종료 후 노출 라벨(웹 LIVE_ENDED_HOME_LABEL / LIVE_ENDED_PANEL_LABEL).
const String liveEndedHomeLabel = 'LIVE 종료 · 최종 결과';
const String liveEndedPanelLabel = '세션 종료 · 최종 결과';

/// 웹 driverAccentColor 매핑(드라이버 코드 → 팀 컬러). 노란색은 사용하지 않는다.
const Map<String, int> _driverAccent = {
  'NOR': 0xFFFF8700,
  'PIA': 0xFFFF8700,
  'VER': 0xFF1E41FF,
  'TSU': 0xFF1E41FF,
  'LEC': 0xFFE80020,
  'HAM': 0xFFE80020,
  'RUS': 0xFF00D2BE,
  'ANT': 0xFF00D2BE,
  'SAI': 0xFF00A3FF,
  'ALB': 0xFF00A3FF,
  'ALO': 0xFF229971,
  'STR': 0xFF229971,
  'GAS': 0xFFFF87BC,
  'COL': 0xFFFF87BC,
  'OCO': 0xFFF4F4F4,
  'BEA': 0xFFF4F4F4,
  'HAD': 0xFF6CC3FF,
  'LAW': 0xFF6CC3FF,
  'HUL': 0xFF4B5563, // 아우디(2026) — 순위 페이지와 동일한 짙은 회색
  'BOR': 0xFF4B5563,
};

Color liveDriverAccent(String code) => Color(_driverAccent[code] ?? 0xFF7880A0);

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
        background: const Color(0x0DFFFFFF), // white/5
        foreground: const Color(0xFF7880A0),
      );
  }
}
