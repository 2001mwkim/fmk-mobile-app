import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_session.dart';

/// 개발용 live.json endpoint (기존 SignalR collector 가 제공).
/// endpoint 는 이 한 곳에서만 바꾼다.
///
/// Android 에뮬레이터에서는 localhost 가 기기 내부를 가리키므로 아래 값으로 교체:
///   const String kLiveJsonUrl = 'http://10.0.2.2:8787/live.json';
const String kLiveJsonUrl = 'http://localhost:8787/live.json';

/// 요청 타임아웃(폴링 주기보다 짧게).
const Duration kLiveFetchTimeout = Duration(seconds: 8);

/// live.json 을 fetch 해서 [LiveSessionSnapshot] 으로 파싱한다.
/// 직접 SignalR 에 연결하지 않고, collector 가 만든 JSON 만 읽는다.
class LiveSessionService {
  const LiveSessionService({this.url = kLiveJsonUrl, this.client});

  final String url;

  /// 테스트 주입용 클라이언트(없으면 매 요청마다 생성/정리).
  final http.Client? client;

  /// 성공 시 스냅샷, 네트워크/파싱 실패 시 null. 예외를 던지지 않는다(앱 크래시 방지).
  Future<LiveSessionSnapshot?> fetch() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(url))
          .timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) return null;
      return parseLiveJson(response.body);
    } catch (_) {
      // 네트워크 오류/타임아웃/파싱 오류 모두 무시하고 null(라이브 UI 숨김).
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// live.json 본문을 파싱. 형식은 `{ "snapshot": {...}, "collector": {...} }`.
/// 어떤 필드든 없거나 null 일 수 있으므로 안전하게 처리하고, 실패하면 null 을 반환한다.
LiveSessionSnapshot? parseLiveJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;

    // collector 는 { snapshot, collector } 로 감싸지만, snapshot 단독도 허용.
    final raw = decoded['snapshot'] ?? decoded;
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();

    return LiveSessionSnapshot(
      status: _parseStatus(map['status']),
      // 원문(ISO) 보존 — KST 표시는 LiveSessionSnapshot.updatedAtLabel 에서 처리.
      updatedAt: _string(map['updatedAt']) ?? '',
      raceId: _string(map['raceId']),
      raceName: _string(map['raceName']),
      sessionType: _string(map['sessionType']),
      sessionName: _string(map['sessionName']),
      currentLap: _int(map['currentLap']),
      totalLaps: _int(map['totalLaps']),
      topThree: _parseDrivers(map['topThree']),
      classification: _parseDrivers(map['classification']),
      endedAt: _dateTime(map['endedAt']),
      visibleUntil: _dateTime(map['visibleUntil']),
    );
  } catch (_) {
    return null;
  }
}

List<LiveDriverPosition> _parseDrivers(dynamic value) {
  if (value is! List) return const [];
  final result = <LiveDriverPosition>[];
  for (final item in value) {
    if (item is! Map) continue;
    final m = item.cast<String, dynamic>();
    final position = _int(m['position']);
    if (position == null) continue;
    result.add(
      LiveDriverPosition(
        position: position,
        code: _string(m['code']) ?? '?',
        displayName: _string(m['displayName']) ?? 'Unknown',
        racingNumber: _string(m['racingNumber']),
        gapToLeader: _string(m['gapToLeader']),
        interval: _string(m['interval']),
      ),
    );
  }
  return result;
}

LiveSessionStatus _parseStatus(dynamic value) {
  switch (_string(value)) {
    case 'live':
      return LiveSessionStatus.live;
    case 'ended':
      return LiveSessionStatus.ended;
    default:
      return LiveSessionStatus.inactive;
  }
}

String? _string(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num) return value.toString();
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}
