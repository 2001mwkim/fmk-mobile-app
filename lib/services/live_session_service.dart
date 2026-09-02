import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/live_session.dart';

/// live.json endpoint (기존 SignalR collector 가 제공).
///
/// 값은 빌드 시 `--dart-define=LIVE_JSON_URL=...` 로 주입할 수 있고,
/// 주입이 없으면 릴리스 빌드는 프로덕션(Railway) URL, 그 외(debug/profile)는
/// 로컬 collector(`http://localhost:8787/live.json`)를 사용한다.
/// 릴리스 기본값을 프로덕션으로 두는 이유: 스토어 빌드에서 주입을 잊으면
/// 라이브가 조용히 죽고, iOS 는 ATS 가 http 를 차단해 증상 파악도 어렵다.
/// `String.fromEnvironment`/`bool.fromEnvironment` 는 const 이고 dart:io 에
/// 의존하지 않아 Web / Windows / Android 어디서든 빌드가 깨지지 않는다.
///
/// 실행 환경별 예시:
///   - Windows desktop : http://localhost:8787/live.json   (기본값, 주입 불필요)
///   - Android emulator: flutter run --dart-define=LIVE_JSON_URL=http://10.0.2.2:8787/live.json
///   - physical device : flutter run --dart-define=LIVE_JSON_URL=`http://PC-LAN-IP:8787/live.json`
///                       (예: http://192.168.0.10:8787/live.json — PC 와 기기가 같은 네트워크)
/// 릴리스(AOT product) 빌드 여부 — `kReleaseMode` 와 같은 판정이지만
/// flutter/foundation 의존 없이 const 로 쓰기 위해 직접 읽는다.
const bool _kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');

const String kLiveJsonUrl = String.fromEnvironment(
  'LIVE_JSON_URL',
  // 릴리스는 Cloudflare(live.formulamagazine.kr, 서울/도쿄 PoP + 5초 엣지 캐시)를
  // 기본으로 — 라이브 폴링을 Vercel 엣지 요청(무료 100만/월 한도)에서 뺀다.
  // Cloudflare 무료는 요청 수를 안 세고 origin(Railway collector) 부하도
  // 사용자 수와 무관하게 분당 12회로 고정된다. 기본값을 Vercel 로 두면 dart-define
  // 없이 빌드했을 때 조용히 Vercel 로 돌아가 한도를 터뜨리므로 기본값 자체를 옮겼다.
  defaultValue: _kIsReleaseBuild
      ? 'https://live.formulamagazine.kr/live.json'
      : 'http://localhost:8787/live.json',
);

/// [kLiveJsonUrl] 이 실패했을 때 대신 시도할 endpoint.
///
/// 2026-08-24 사고 대응. `live.formulamagazine.kr` 로 네임서버를 옮긴 직후,
/// 국내 ISP 리졸버들이 옛 위임(dns3/dns4.viaweb.co.kr)을 계속 물고 있어서
/// 해당 호스트가 **간헐적으로 NXDOMAIN** 이 됐다(리졸버 클러스터의 노드마다
/// 캐시가 갈려 같은 통신사에서도 성공/실패가 번갈아 나왔다). 라이브 URL 이
/// 단일 호스트에 묶여 있던 탓에 0.1.6 안드로이드의 라이브 센터가 통째로 비었다.
///
/// 폴백을 `www` 로 두는 이유: 이 호스트는 **옛 존(비아웹)과 새 존(Cloudflare)
/// 양쪽 모두에** 있어서, 리졸버가 어느 위임을 물고 있든 100% 조회된다.
/// 즉 위임이 갈라진 동안에도 확실히 살아 있는 유일한 경로다.
///
/// 폴백은 Vercel 엣지 요청(무료 100만/월)을 쓰므로 상시 경로가 되면 안 된다
/// — [LiveSessionService] 가 성공한 endpoint 를 기억해, DNS 가 정상화되면
/// 자연스럽게 Cloudflare 로 돌아간다.
const String kLiveJsonFallbackUrl = String.fromEnvironment(
  'LIVE_JSON_FALLBACK_URL',
  // 로컬 collector 로 개발할 땐 폴백이 없다(빈 문자열 = 폴백 비활성).
  defaultValue: _kIsReleaseBuild
      ? 'https://www.formulamagazine.kr/api/live'
      : '',
);

/// 레이스/스프린트 중 폴링을 10초로 당길지 여부(기본 true).
///
/// 원래는 꺼 두었다 — 주기를 절반으로 줄이면 요청 수가 두 배가 되는데, 당시
/// 릴리스 URL 이던 Vercel `/api/live` 는 무료 플랜에서 **캐시 HIT 도 엣지 요청으로
/// 계산**해 비용이 그대로 두 배가 됐다. 라이브를 Cloudflare 로 옮기면서
/// ([kLiveJsonUrl]) 그 제약이 사라져 기본값을 켬으로 바꿨다. Cloudflare 는 요청 수를
/// 세지 않고, 엣지 캐시가 흡수하므로 origin(Railway) 부하도 늘지 않는다.
///
/// [kLiveJsonUrl] 과 같은 이유로 **기본값 자체를 켬으로 둔다** — dart-define 을 깜빡한
/// 빌드가 조용히 예전 동작으로 돌아가지 않게 한다. 되돌릴 때만 명시적으로:
///   flutter build appbundle --release --dart-define=LIVE_FAST_POLL=false
/// 연습/퀄리는 이 값과 무관하게 20초를 유지한다(랩타임 갱신이 드물다).
const bool kLiveFastPollDuringRace = bool.fromEnvironment(
  'LIVE_FAST_POLL',
  defaultValue: true,
);

/// Live Activity 푸시 토큰 등록 endpoint — 폴링 URL 과 달리 collector
/// (Railway) 직결이어야 한다(Vercel 은 이 경로를 중계하지 않음).
const String kLiveActivityRegisterUrl = String.fromEnvironment(
  'LIVE_ACTIVITY_REGISTER_URL',
  defaultValue: _kIsReleaseBuild
      ? 'https://live-production-c03d.up.railway.app/live-activity/register'
      : 'http://localhost:8787/live-activity/register',
);

/// 요청 타임아웃(폴링 주기보다 짧게).
const Duration kLiveFetchTimeout = Duration(seconds: 8);

/// live.json 을 fetch 해서 [LiveSessionSnapshot] 으로 파싱한다.
/// 직접 SignalR 에 연결하지 않고, collector 가 만든 JSON 만 읽는다.
class LiveSessionService {
  LiveSessionService({
    this.url = kLiveJsonUrl,
    this.fallbackUrl = kLiveJsonFallbackUrl,
    this.client,
    this.delaySeconds = 0,
  });

  final String url;

  /// [url] 이 실패했을 때 시도할 대체 endpoint. 빈 문자열이면 폴백하지 않는다.
  final String fallbackUrl;

  /// 테스트 주입용 클라이언트(없으면 매 요청마다 생성/정리).
  final http.Client? client;

  /// 라이브 센터 전용 재생 지연. 전역 라이브 서비스는 기본값 0을 유지한다.
  final int delaySeconds;

  /// 시도 순서. 앞이 1순위다.
  late final List<String> endpoints = <String>[
    url,
    if (fallbackUrl.isNotEmpty && fallbackUrl != url) fallbackUrl,
  ];

  /// 마지막으로 성공한 endpoint 의 인덱스 — 다음 폴링의 1순위가 된다.
  ///
  /// DNS 장애처럼 한쪽이 오래 죽어 있을 때 매번 죽은 쪽부터 찌르면 폴링마다
  /// 타임아웃을 먹는다. 반대로 정상화되면 1순위가 다시 성공하므로 별도 복구
  /// 로직 없이 원래 경로로 돌아온다.
  int _preferredIndex = 0;

  /// 현재 1순위 endpoint. 폴백이 쓰이고 있는지 확인·로깅용.
  String get activeUrl => endpoints[_preferredIndex];

  /// 성공 시 스냅샷, 네트워크/파싱 실패 시 null. 예외를 던지지 않는다(앱 크래시 방지).
  Future<LiveSessionSnapshot?> fetch() async {
    return (await fetchResult()).snapshot;
  }

  /// fetch 성공 여부와 파싱된 스냅샷을 함께 반환한다.
  ///
  /// `succeeded == false` 는 [endpoints] 를 **전부** 시도했는데도 접근하지 못한
  /// 경우다. `succeeded == true && snapshot == null` 은 응답은 받았지만 표시할
  /// 스냅샷이 없는 경우로, 정상 응답이므로 폴백으로 넘어가지 않는다.
  Future<LiveSessionFetchResult> fetchResult() async {
    for (var offset = 0; offset < endpoints.length; offset++) {
      final index = (_preferredIndex + offset) % endpoints.length;
      final result = await _fetchFrom(endpoints[index]);
      if (result.succeeded) {
        _preferredIndex = index;
        return result;
      }
    }
    return const LiveSessionFetchResult.failed();
  }

  Future<LiveSessionFetchResult> _fetchFrom(String endpoint) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(_requestUri(endpoint))
          .timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) {
        return const LiveSessionFetchResult.failed();
      }
      // bodyBytes 로 직접 디코딩한다 — Vercel 폴백은 charset 없는
      // `application/json` 을 주는데, http 패키지의 `body` 는 그 경우 latin1 로
      // 풀어서 드라이버 한글 이름이 깨진다.
      final snapshot = parseLiveJson(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      // 구버전 서버가 delay 쿼리를 무시하면 최신 데이터가 스포일러가 된다.
      // 요청한 지연값과 수집 시각이 모두 확인된 응답만 화면에 전달한다.
      if (delaySeconds > 0 &&
          snapshot != null &&
          (snapshot.playbackDelaySeconds != delaySeconds ||
              (snapshot.playbackCapturedAt == null &&
                  _hasSessionContent(snapshot)))) {
        return const LiveSessionFetchResult.success(null);
      }
      return LiveSessionFetchResult.success(snapshot);
    } catch (_) {
      // 네트워크 오류/타임아웃/파싱 오류 모두 무시하고 실패로 처리(다음 endpoint 시도).
      return const LiveSessionFetchResult.failed();
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Uri _requestUri(String endpoint) {
    final uri = Uri.parse(endpoint);
    if (delaySeconds <= 0) return uri;
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        'delay': '$delaySeconds',
      },
    );
  }

  bool _hasSessionContent(LiveSessionSnapshot snapshot) {
    return (snapshot.raceId?.isNotEmpty ?? false) ||
        (snapshot.raceName?.isNotEmpty ?? false) ||
        (snapshot.sessionKey?.isNotEmpty ?? false) ||
        (snapshot.sessionType?.isNotEmpty ?? false) ||
        (snapshot.sessionName?.isNotEmpty ?? false) ||
        snapshot.classification.isNotEmpty ||
        snapshot.topThree.isNotEmpty;
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
    // 명시적인 snapshot:null은 wrapper 자체를 빈 스냅샷으로 오인하지 않는다.
    final raw = decoded.containsKey('snapshot') ? decoded['snapshot'] : decoded;
    if (raw == null) return null;
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final playbackRaw = decoded['playback'];
    final playback = playbackRaw is Map
        ? playbackRaw.cast<String, dynamic>()
        : const <String, dynamic>{};

    return LiveSessionSnapshot(
      status: _parseStatus(map['status']),
      // 원문(ISO) 보존 — KST 표시는 LiveSessionSnapshot.updatedAtLabel 에서 처리.
      updatedAt: _string(map['updatedAt']) ?? '',
      raceId: _string(map['raceId']),
      raceName: _string(map['raceName']),
      sessionKey: _string(map['sessionKey']),
      sessionType: _string(map['sessionType']),
      sessionName: _string(map['sessionName']),
      qualifyingPart: _int(map['qualifyingPart'] ?? map['sessionPart']),
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
      clockStopped: _bool(map['clockStopped']) ?? false,
      weather: _parseWeather(map['weather'] ?? map['weatherData']),
      raceControlMessages: _parseRaceControlMessages(
        map['raceControlMessages'] ?? map['raceControl'],
      ),
      // lastSession 은 스냅샷이 아니라 body 최상위 필드(스냅샷과 수명이 다름).
      lastSession: _parseLastSession(decoded['lastSession']),
      playbackCapturedAt: _dateTime(playback['capturedAt']),
      playbackDelaySeconds: _int(playback['requestedDelaySeconds']) ?? 0,
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
        qualifyingEliminatedIn: _int(m['qualifyingEliminatedIn']),
        speedTrap: _string(m['speedTrap'] ?? m['speed']),
        lastLapFlag: _string(m['lastLapFlag']),
        bestLapIsOverall: _bool(m['bestLapIsOverall']) ?? false,
        sectorDetails: _parseSectorDetails(m['sectorDetails']),
        bestSectors: [
          if (m['bestSectors'] is List)
            for (final raw in m['bestSectors'] as List) _string(raw),
        ],
        speedI1: _string(m['speedI1']),
        speedI2: _string(m['speedI2']),
        stints: _parseStints(m['stints']),
      ),
    );
  }
  return result;
}

List<LiveSectorDetail> _parseSectorDetails(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final raw in value)
      if (raw is Map)
        LiveSectorDetail(
          value: _string(raw['value']),
          flag: _string(raw['flag']),
          segments: [
            if (raw['segments'] is List)
              for (final code in raw['segments'] as List)
                if (_int(code) != null) _int(code)!,
          ],
        ),
  ];
}

/// 직전 세션 결과 파싱 — 순위가 비어 있으면 쓸모가 없으므로 null.
LiveLastSession? _parseLastSession(dynamic value) {
  if (value is! Map) return null;
  final map = value.cast<String, dynamic>();
  final classification = _parseDrivers(map['classification']);
  if (classification.isEmpty) return null;
  return LiveLastSession(
    raceId: _string(map['raceId']),
    raceName: _string(map['raceName']),
    sessionType: _string(map['sessionType']),
    sessionName: _string(map['sessionName']),
    endedAt: _dateTime(map['endedAt']),
    classification: classification,
  );
}

List<LiveStint> _parseStints(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final raw in value)
      if (raw is Map)
        LiveStint(compound: _string(raw['compound']), laps: _int(raw['laps'])),
  ];
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
