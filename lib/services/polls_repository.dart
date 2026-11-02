import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/race_poll.dart';
import 'error_reporting.dart';
import 'live_session_service.dart';

/// 팬 투표(우승·폴 예측, 레이스 평점) — collector `/polls.json`, `/polls/vote`.
///
/// live.json 과 같은 Cloudflare 호스트를 쓴다(Vercel 0건). 조회는 GP 상세를
/// 열 때만, 메모리 60초 캐시 → 디바이스당 하루 수 건 수준. 계정이 없으므로
/// 설치마다 무작위 UUID v4 를 만들어 보내고, 서버는 소금 친 해시만 저장한다.
String? pollsBaseUrlFor(String liveJsonUrl) {
  const suffix = '/live.json';
  if (!liveJsonUrl.endsWith(suffix)) return null;
  return liveJsonUrl.substring(0, liveJsonUrl.length - suffix.length);
}

const String _deviceIdKey = 'polls_device_id';
String _myVoteKey(String raceId, PollKind kind) =>
    'poll_vote_${raceId}_${kind.wire}';

/// 투표 실패 사유 — 화면 안내 문구를 고르는 데 쓴다.
enum VoteError { closed, rateLimited, failed }

class VoteResult {
  const VoteResult.ok(RacePoll this.poll) : error = null;
  const VoteResult.failed(VoteError this.error) : poll = null;

  final RacePoll? poll;
  final VoteError? error;
}

class PollsRepository {
  PollsRepository({String? baseUrl, this.client})
    : baseUrl = baseUrl ?? pollsBaseUrlFor(kLiveJsonUrl);

  /// null 이면(지원 안 하는 live URL) 투표 카드를 띄우지 않는다.
  final String? baseUrl;
  final http.Client? client;

  static const Duration _cacheTtl = Duration(seconds: 60);
  static final Map<String, (DateTime, RacePoll)> _cache = {};

  bool get isEnabled => baseUrl != null && baseUrl!.isNotEmpty;

  /// 캐시는 화면마다 새로 만드는 저장소끼리 공유하려고 static 이다 — 테스트 격리용.
  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// 집계 조회. 미지원·미존재(404)·실패는 null.
  Future<RacePoll?> fetch(String raceId, {bool force = false}) async {
    if (!isEnabled) return null;
    final cached = _cache[raceId];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.$1) < _cacheTtl) {
      return cached.$2;
    }
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(
            Uri.parse(
              '$baseUrl/polls.json',
            ).replace(queryParameters: {'raceId': raceId}),
          )
          .timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) {
        reportHttpStatus('polls', response.statusCode);
        return null;
      }
      final poll = RacePoll.tryParse(utf8.decode(response.bodyBytes));
      if (poll != null) _cache[raceId] = (DateTime.now(), poll);
      return poll;
    } catch (error, stackTrace) {
      reportSilentFailure('polls', error, stackTrace);
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// 투표(같은 종류를 다시 보내면 서버가 이전 표를 바꾼다).
  Future<VoteResult> vote({
    required String raceId,
    required PollKind kind,
    required Object value,
  }) async {
    if (!isEnabled) return const VoteResult.failed(VoteError.failed);
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse('$baseUrl/polls/vote'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'raceId': raceId,
              'kind': kind.wire,
              'value': value,
              'deviceId': await deviceId(),
            }),
          )
          .timeout(kLiveFetchTimeout);
      switch (response.statusCode) {
        case 200:
          final poll = RacePoll.tryParse(utf8.decode(response.bodyBytes));
          if (poll == null) return const VoteResult.failed(VoteError.failed);
          _cache[raceId] = (DateTime.now(), poll);
          await _saveMyVote(raceId, kind, '$value');
          return VoteResult.ok(poll);
        case 409:
          return const VoteResult.failed(VoteError.closed);
        case 429:
          return const VoteResult.failed(VoteError.rateLimited);
        default:
          reportHttpStatus('polls_vote', response.statusCode);
          return const VoteResult.failed(VoteError.failed);
      }
    } catch (error, stackTrace) {
      reportSilentFailure('polls_vote', error, stackTrace);
      return const VoteResult.failed(VoteError.failed);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// 이 기기에서 낸 표(화면에 '내 예측' 으로 보여준다). 없으면 null.
  Future<String?> myVote(String raceId, PollKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_myVoteKey(raceId, kind));
  }

  Future<void> _saveMyVote(String raceId, PollKind kind, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_myVoteKey(raceId, kind), value);
  }

  /// 설치별 익명 식별자(UUID v4). 처음 투표할 때 만든다.
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && isUuidV4(existing)) return existing;
    final created = generateUuidV4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }
}

/// 의존성 없이 만드는 UUID v4(RFC 4122). 보안 난수를 쓴다.
String generateUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

bool isUuidV4(String value) => RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
).hasMatch(value);
