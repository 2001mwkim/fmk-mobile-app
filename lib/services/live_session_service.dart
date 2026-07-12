import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_session.dart';

/// 개발용 live.json endpoint (기존 SignalR collector 가 제공).
///
/// 값은 빌드 시 `--dart-define=LIVE_JSON_URL=...` 로 주입할 수 있고,
/// 주입이 없으면 기본값(`http://localhost:8787/live.json`)을 사용한다.
/// `String.fromEnvironment` 는 const 이고 dart:io 에 의존하지 않아
/// Web / Windows / Android 어디서든 빌드가 깨지지 않는다.
///
/// 실행 환경별 예시:
///   - Windows desktop : http://localhost:8787/live.json   (기본값, 주입 불필요)
///   - Android emulator: flutter run --dart-define=LIVE_JSON_URL=http://10.0.2.2:8787/live.json
///   - physical device : flutter run --dart-define=LIVE_JSON_URL=`http://PC-LAN-IP:8787/live.json`
///                       (예: http://192.168.0.10:8787/live.json — PC 와 기기가 같은 네트워크)
const String kLiveJsonUrl = String.fromEnvironment(
  'LIVE_JSON_URL',
  defaultValue: 'http://localhost:8787/live.json',
);

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
    return (await fetchResult()).snapshot;
  }

  /// fetch 성공 여부와 파싱된 스냅샷을 함께 반환한다.
  ///
  /// `succeeded == false` 는 네트워크/타임아웃/HTTP 오류처럼 collector 에 접근하지
  /// 못한 경우다. `succeeded == true && snapshot == null` 은 응답은 받았지만
  /// 표시할 스냅샷이 없는 경우로 취급한다.
  Future<LiveSessionFetchResult> fetchResult() async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(url))
          .timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) {
        return const LiveSessionFetchResult.failed();
      }
      return LiveSessionFetchResult.success(parseLiveJson(response.body));
    } catch (_) {
      // 네트워크 오류/타임아웃/파싱 오류 모두 무시하고 null(라이브 UI 숨김).
      return const LiveSessionFetchResult.failed();
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

class LiveSessionFetchResult {
  const LiveSessionFetchResult._({required this.succeeded, this.snapshot});

  const LiveSessionFetchResult.success(LiveSessionSnapshot? snapshot)
    : this._(succeeded: true, snapshot: snapshot);

  const LiveSessionFetchResult.failed() : this._(succeeded: false);

  final bool succeeded;
  final LiveSessionSnapshot? snapshot;
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
      sessionKey: _string(map['sessionKey']),
      sessionType: _string(map['sessionType']),
      sessionName: _string(map['sessionName']),
      currentLap: _int(map['currentLap']),
      totalLaps: _int(map['totalLaps']),
      topThree: _parseDrivers(map['topThree']),
      classification: _parseDrivers(map['classification']),
      endedAt: _dateTime(map['endedAt']),
      visibleUntil: _dateTime(map['visibleUntil']),
      trackStatus: _string(map['trackStatus'] ?? map['trackStatusCode']),
      trackStatusMessage: _string(
        map['trackStatusMessage'] ?? map['trackStatusLabel'],
      ),
      remainingTime: _string(map['remainingTime'] ?? map['sessionTimeLeft']),
      weather: _parseWeather(map['weather'] ?? map['weatherData']),
      raceControlMessages: _parseRaceControlMessages(
        map['raceControlMessages'] ?? map['raceControl'],
      ),
    );
  } catch (_) {
    return null;
  }
}

/// 한 목록에서 받아들일 최대 드라이버 수.
/// F1 그리드는 20대라 정상 응답은 이보다 훨씬 작다. collector 가 오염되거나
/// 다른 서버가 응답을 위조해 초대형 배열을 내려보내도 앱이 무한정 파싱/렌더링
/// 하지 않도록 방어한다(방어적 상한 — CWE-20/무제한 자원 소비 대응).
const int _maxDriversPerList = 40;

List<LiveDriverPosition> _parseDrivers(dynamic value) {
  if (value is! List) return const [];
  final result = <LiveDriverPosition>[];
  for (final item in value) {
    if (result.length >= _maxDriversPerList) break;
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
        lapTime: _string(m['lapTime']),
        displayTime: _string(m['displayTime']),
        lastLapTime: _string(m['lastLapTime']),
        bestLapTime: _string(m['bestLapTime']),
        personalBestLapTime: _string(m['personalBestLapTime']),
        sector1: _string(m['sector1'] ?? m['sector1Time']),
        sector2: _string(m['sector2'] ?? m['sector2Time']),
        sector3: _string(m['sector3'] ?? m['sector3Time']),
        compound: _string(m['compound'] ?? m['tyreCompound']),
        tyreAge: _int(m['tyreAge'] ?? m['tyreLaps']),
        stint: _int(m['stint']),
        pitStops: _int(m['pitStops'] ?? m['numberOfPitStops']),
        inPit: _bool(m['inPit'] ?? m['pit']) ?? false,
        retired: _bool(m['retired'] ?? m['stopped']) ?? false,
        speedTrap: _string(m['speedTrap'] ?? m['speed']),
      ),
    );
  }
  return result;
}

LiveWeather? _parseWeather(dynamic value) {
  if (value is! Map) return null;
  final map = value.cast<String, dynamic>();
  final weather = LiveWeather(
    airTemperature: _double(
      map['airTemperature'] ?? map['airTemp'] ?? map['AirTemp'],
    ),
    trackTemperature: _double(
      map['trackTemperature'] ?? map['trackTemp'] ?? map['TrackTemp'],
    ),
    humidity: _double(map['humidity'] ?? map['Humidity']),
    pressure: _double(map['pressure'] ?? map['Pressure']),
    rainfall: _bool(map['rainfall'] ?? map['Rainfall']),
    windSpeed: _double(map['windSpeed'] ?? map['WindSpeed']),
    windDirection: _int(map['windDirection'] ?? map['WindDirection']),
  );
  if (weather.airTemperature == null &&
      weather.trackTemperature == null &&
      weather.humidity == null &&
      weather.pressure == null &&
      weather.rainfall == null &&
      weather.windSpeed == null) {
    return null;
  }
  return weather;
}

List<LiveRaceControlMessage> _parseRaceControlMessages(dynamic value) {
  final rawItems = value is List
      ? value
      : value is Map
      ? value.values.toList()
      : const <dynamic>[];
  final result = <LiveRaceControlMessage>[];
  for (final item in rawItems) {
    if (item is! Map) continue;
    final map = item.cast<String, dynamic>();
    final message = _string(map['message'] ?? map['Message']);
    if (message == null) continue;
    result.add(
      LiveRaceControlMessage(
        message: message,
        timestamp: _dateTime(map['timestamp'] ?? map['utc'] ?? map['Utc']),
        category: _string(map['category'] ?? map['Category']),
        flag: _string(map['flag'] ?? map['Flag']),
        scope: _string(map['scope'] ?? map['Scope']),
        racingNumber: _string(map['racingNumber'] ?? map['RacingNumber']),
      ),
    );
  }
  result.sort((a, b) {
    final aTime = a.timestamp;
    final bTime = b.timestamp;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return result.take(30).toList(growable: false);
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

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool? _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value is String) return DateTime.tryParse(value.trim());
  return null;
}
