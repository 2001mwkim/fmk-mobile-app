import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/race_result.dart';
import 'news_repository.dart' show kNewsApiBaseUrl;

/// 결과 요청 타임아웃(순위/뉴스와 동일 — 화면 응답성 우선).
const Duration kRaceResultsFetchTimeout = Duration(seconds: 8);

/// 서버에서 받은 한 그랑프리의 레이스 결과.
class RaceResultData {
  const RaceResultData({required this.status, required this.entries});

  /// 'official'(공식 결과) 또는 'provisional'(잠정 결과).
  final String status;
  final List<RaceResultEntry> entries;

  bool get isOfficial => status == 'official';
}

/// 가장 최근에 결과가 존재하는 레이스(홈 "최근 레이스 결과" 카드용).
class LatestRaceResult {
  const LatestRaceResult({
    required this.raceId,
    required this.data,
    this.sessionType = 'RACE',
  });

  final String raceId;
  final RaceResultData data;
  final String sessionType;
}

/// 레이스 결과 공급 계층.
///
/// 서버(F1DB 주기 갱신 → Railway `/race-results.json` → Vercel
/// `/api/race-results`)에서 그랑프리별 결과를 받아온다. **실패/미존재 시
/// null** — 화면은 번들된 정적 결과가 있으면 그걸, 없으면 "결과 데이터
/// 준비 중" 카드를 유지한다(크래시 없음).
///
/// 조회 키는 round 가 아니라 raceId 를 쓴다 — 취소 GP 때문에 F1DB 라운드
/// 번호와 앱 라운드 번호가 어긋날 수 있어서(서버가 circuitId 로 조인해
/// 앱과 같은 raceId 를 내려준다).
abstract class RaceResultsRepository {
  Future<RaceResultData?> fetchResult({required String raceId, int season});

  /// 가장 최근 결과가 있는 레이스 1개(홈 카드용). 없거나 실패하면 null.
  Future<LatestRaceResult?> fetchLatest({int season});
}

/// 실서버 구현(앱 기본값). origin 은 뉴스/순위와 같은 Vercel 도메인
/// ([kNewsApiBaseUrl] 공용 — `--dart-define=NEWS_API_BASE_URL` 로 재정의).
class HttpRaceResultsRepository implements RaceResultsRepository {
  const HttpRaceResultsRepository({
    this.baseUrl = kNewsApiBaseUrl,
    this.client,
  });

  final String baseUrl;

  /// 테스트 주입용 클라이언트(없으면 매 요청마다 생성/정리).
  final http.Client? client;

  @override
  Future<RaceResultData?> fetchResult({
    required String raceId,
    int season = 2026,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse(baseUrl).replace(
        path: '/api/race-results',
        queryParameters: {'season': '$season', 'raceId': raceId},
      );
      final response = await httpClient
          .get(uri)
          .timeout(kRaceResultsFetchTimeout);
      if (response.statusCode != 200) return null;
      // JSON 은 UTF-8 (RFC 8259) — 한글 이름 깨짐 방지(뉴스와 동일 규칙).
      return parseRaceResultJson(
        utf8.decode(response.bodyBytes),
        raceId: raceId,
      );
    } catch (_) {
      // 네트워크/타임아웃/파싱 오류 → null(기존 카드 유지).
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  @override
  Future<LatestRaceResult?> fetchLatest({int season = 2026}) async {
    final httpClient = client ?? http.Client();
    try {
      // raceId 필터 없이 시즌 전체를 받아 마지막(최신) 라운드를 고른다.
      final uri = Uri.parse(baseUrl).replace(
        path: '/api/race-results',
        queryParameters: {'season': '$season'},
      );
      final response = await httpClient
          .get(uri)
          .timeout(kRaceResultsFetchTimeout);
      if (response.statusCode != 200) return null;
      return parseLatestRaceResultJson(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null; // 홈 카드는 실패 시 그냥 표시하지 않는다.
    } finally {
      if (client == null) httpClient.close();
    }
  }
}

/// 응답에서 가장 최근(서버가 라운드 오름차순 정렬 → 마지막 항목) 유효 결과를
/// 찾아 파싱한다. 유효 결과가 하나도 없으면 null(홈 카드 미표시).
LatestRaceResult? parseLatestRaceResultJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['races'] is! List) return null;

    LatestRaceResult? latest;
    for (final rawRace in decoded['races'] as List) {
      if (rawRace is! Map || rawRace['raceId'] is! String) continue;
      final raceId = rawRace['raceId'] as String;
      if (rawRace['sessions'] is List) {
        for (final rawSession in rawRace['sessions'] as List) {
          if (rawSession is! Map || rawSession['sessionType'] is! String) {
            continue;
          }
          final data = _parseResultData(rawSession);
          if (data != null) {
            latest = LatestRaceResult(
              raceId: raceId,
              data: data,
              sessionType: rawSession['sessionType'] as String,
            );
          }
        }
      } else {
        final data = parseRaceResultJson(body, raceId: raceId);
        if (data != null) latest = LatestRaceResult(raceId: raceId, data: data);
      }
    }
    return latest;
  } catch (_) {
    return null;
  }
}

RaceResultData? _parseResultData(Map rawResult) {
  final entries = <RaceResultEntry>[];
  if (rawResult['results'] is List) {
    for (final rawRow in rawResult['results'] as List) {
      if (rawRow is! Map) continue;
      final row = RaceResultEntry.fromJson(rawRow.cast<String, dynamic>());
      if (row != null) entries.add(row);
    }
  }
  if (entries.length < 10) return null;
  entries.sort((a, b) => a.position.compareTo(b.position));
  return RaceResultData(
    status: rawResult['status'] == 'provisional' ? 'provisional' : 'official',
    entries: entries,
  );
}

/// 응답에서 [raceId] 의 결과를 찾아 파싱한다. 깨진 행은 건너뛰되,
/// 완주 분류로 보기 어려운 규모(10행 미만)면 불완전 응답으로 보고 null.
RaceResultData? parseRaceResultJson(String body, {required String raceId}) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['races'] is! List) return null;

    for (final rawRace in decoded['races'] as List) {
      if (rawRace is! Map || rawRace['raceId'] != raceId) continue;

      return _parseResultData(rawRace);
    }
    return null; // 해당 raceId 결과 없음(아직 미개최 등)
  } catch (_) {
    return null;
  }
}
