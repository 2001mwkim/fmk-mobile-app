import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/standing.dart';
import 'news_repository.dart' show kNewsApiBaseUrl;

/// 순위 요청 타임아웃(뉴스와 동일 — 화면 응답성 우선).
const Duration kStandingsFetchTimeout = Duration(seconds: 8);
const Duration kStandingsCacheTtl = Duration(hours: 6);

/// 서버에서 받은 챔피언십 순위 스냅샷.
class StandingsSnapshot {
  const StandingsSnapshot({
    required this.driverStandings,
    required this.constructorStandings,
  });

  final List<DriverStanding> driverStandings;
  final List<ConstructorStanding> constructorStandings;
}

/// 챔피언십 순위 공급 계층.
///
/// 서버(F1DB 주기 갱신 → Railway `/standings.json` → Vercel `/api/standings`)
/// 에서 최신 순위를 받아온다. **실패하면 null** — 화면은 번들된 정적 순위
/// (lib/data/standings.dart)를 그대로 유지한다(빈 화면·크래시 없음).
/// 뉴스와 달리 정적 폴백을 쓰는 이유: 순위는 "조금 오래된 데이터"가
/// "빈 화면"보다 훨씬 낫기 때문.
abstract class StandingsRepository {
  Future<StandingsSnapshot?> fetchLatest();
}

/// 실서버 구현(앱 기본값). origin 은 뉴스와 같은 Vercel 도메인
/// ([kNewsApiBaseUrl] 공용 — dev/prod 분리도 같은 dart-define 한 곳).
class HttpStandingsRepository implements StandingsRepository {
  const HttpStandingsRepository({this.baseUrl = kNewsApiBaseUrl, this.client});

  final String baseUrl;

  /// 테스트 주입용 클라이언트(없으면 매 요청마다 생성/정리).
  final http.Client? client;

  static const _cacheBodyKey = 'standings_api_cache_body_v1';
  static const _cacheTimeKey = 'standings_api_cache_time_v1';
  static String? _memoryBody;
  static DateTime? _memoryFetchedAt;
  static Future<StandingsSnapshot?>? _sharedLoad;

  @override
  Future<StandingsSnapshot?> fetchLatest() async {
    // Injected clients are used by tests and callers that explicitly want an
    // isolated request. Production callers share one persistent six-hour
    // cache, including concurrent requests made while the app is starting.
    if (client != null || baseUrl != kNewsApiBaseUrl) {
      final body = await _fetchBody();
      return body == null ? null : parseStandingsJson(body);
    }

    final pending = _sharedLoad;
    if (pending != null) return pending;
    final load = _loadShared();
    _sharedLoad = load;
    try {
      return await load;
    } finally {
      if (identical(_sharedLoad, load)) _sharedLoad = null;
    }
  }

  Future<StandingsSnapshot?> _loadShared() async {
    final now = DateTime.now();
    final memoryBody = _memoryBody;
    final memoryAt = _memoryFetchedAt;
    if (memoryBody != null &&
        memoryAt != null &&
        now.difference(memoryAt) < kStandingsCacheTtl) {
      final cached = parseStandingsJson(memoryBody);
      if (cached != null) return cached;
    }

    final preferences = await SharedPreferences.getInstance();
    final diskBody = preferences.getString(_cacheBodyKey);
    final diskTimeMillis = preferences.getInt(_cacheTimeKey);
    final diskAt = diskTimeMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(diskTimeMillis);
    if (diskBody != null &&
        diskAt != null &&
        now.difference(diskAt) < kStandingsCacheTtl) {
      final cached = parseStandingsJson(diskBody);
      if (cached != null) {
        _memoryBody = diskBody;
        _memoryFetchedAt = diskAt;
        return cached;
      }
    }

    final freshBody = await _fetchBody();
    final fresh = freshBody == null ? null : parseStandingsJson(freshBody);
    if (fresh != null) {
      _memoryBody = freshBody;
      _memoryFetchedAt = now;
      await Future.wait([
        preferences.setString(_cacheBodyKey, freshBody!),
        preferences.setInt(_cacheTimeKey, now.millisecondsSinceEpoch),
      ]);
      return fresh;
    }

    // A stale disk value is still preferable to an empty screen when the
    // network is temporarily unavailable.
    return diskBody == null ? null : parseStandingsJson(diskBody);
  }

  Future<String?> _fetchBody() async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(baseUrl).replace(path: '/api/standings');
      final response = await httpClient
          .get(uri)
          .timeout(kStandingsFetchTimeout);
      if (response.statusCode != 200) return null;
      // JSON 은 UTF-8 (RFC 8259) — 한글 이름 깨짐 방지(뉴스와 동일 규칙).
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      // 네트워크/타임아웃/파싱 오류 → null(정적 데이터 유지).
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// 순위 응답 파싱. 깨진 항목은 건너뛰되, 결과가 그리드 규모에 못 미치면
/// (드라이버 10명/팀 5팀 미만) 불완전 응답으로 보고 null — 부분 순위를
/// 보여주는 것보다 정적 데이터 유지가 낫다.
StandingsSnapshot? parseStandingsJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;

    final drivers = <DriverStanding>[];
    if (decoded['driverStandings'] is List) {
      for (final raw in decoded['driverStandings'] as List) {
        if (raw is! Map) continue;
        final row = DriverStanding.fromJson(raw.cast<String, dynamic>());
        if (row != null) drivers.add(row);
      }
    }
    final constructors = <ConstructorStanding>[];
    if (decoded['constructorStandings'] is List) {
      for (final raw in decoded['constructorStandings'] as List) {
        if (raw is! Map) continue;
        final row = ConstructorStanding.fromJson(raw.cast<String, dynamic>());
        if (row != null) constructors.add(row);
      }
    }

    if (drivers.length < 10 || constructors.length < 5) return null;
    drivers.sort((a, b) => a.position.compareTo(b.position));
    constructors.sort((a, b) => a.position.compareTo(b.position));
    return StandingsSnapshot(
      driverStandings: drivers,
      constructorStandings: constructors,
    );
  } catch (_) {
    return null;
  }
}
