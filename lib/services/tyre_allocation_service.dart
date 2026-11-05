import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gp_guide.dart';
import 'error_reporting.dart';

/// GP별 피렐리 타이어 컴파운드 원격 파일.
///
/// collector(fmk-f1-calendar `data/tyres.json`)가 `/tyres.json` 으로 서빙하고
/// Cloudflare 가 5분 캐시한다(Vercel 미사용). 앱 번들 `gp_guides.dart` 의 정적값보다
/// 우선한다 — 시즌 후반 GP 는 피렐리가 2~4주 전에야 발표해서, 앱 빌드 시점엔
/// 비어 있기 마련이다(2026-11 브라질 GP 가 "발표 예정" 으로 남아 있던 일).
const bool _kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');
const String kTyresUrl = String.fromEnvironment(
  'TYRES_URL',
  defaultValue: _kIsReleaseBuild
      ? 'https://live.formulamagazine.kr/tyres.json'
      : 'http://localhost:8787/tyres.json',
);

/// 파일은 사람이 GP 마다 한 번 올리므로 6시간이면 충분하다
/// (GP 상세를 열 때만 확인 — 디바이스당 하루 최대 4건).
const Duration kTyresCacheTtl = Duration(hours: 6);

const String tyresCachePrefsKey = 'tyres_cache_json';
const String tyresCacheAtPrefsKey = 'tyres_cache_at_ms';

final RegExp _compound = RegExp(r'^C[0-6]$');

/// `{ races: { "<raceId>": { hard, medium, soft } } }` 파싱. 형식이 틀린 항목은 버린다.
Map<String, TyreAllocation> parseTyreAllocations(Object? body) {
  final result = <String, TyreAllocation>{};
  if (body is! Map) return result;
  final races = body['races'];
  if (races is! Map) return result;
  races.forEach((raceId, value) {
    if (raceId is! String || value is! Map) return;
    final hard = value['hard'];
    final medium = value['medium'];
    final soft = value['soft'];
    if (hard is! String || medium is! String || soft is! String) return;
    if (![hard, medium, soft].every(_compound.hasMatch)) return;
    result[raceId] = TyreAllocation(hard: hard, medium: medium, soft: soft);
  });
  return result;
}

class TyreAllocationService {
  TyreAllocationService({http.Client? client, DateTime Function()? clock})
    // ignore: prefer_initializing_formals
    : _client = client,
      _clock = clock ?? DateTime.now;

  static final TyreAllocationService instance = TyreAllocationService();

  final http.Client? _client;
  final DateTime Function() _clock;
  Map<String, TyreAllocation>? _memory;
  DateTime? _memoryAt;
  Future<Map<String, TyreAllocation>>? _inFlight;

  /// 원격 할당 전체. 실패하면 마지막 캐시, 그마저 없으면 빈 맵(정적값 사용).
  Future<Map<String, TyreAllocation>> load() {
    final memory = _memory;
    final at = _memoryAt;
    if (memory != null &&
        at != null &&
        _clock().difference(at) < kTyresCacheTtl) {
      return Future.value(memory);
    }
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<Map<String, TyreAllocation>> _load() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return const {}; // 플러그인 없는 환경(일부 테스트) — 정적값으로.
    }
    final cachedRaw = prefs.getString(tyresCachePrefsKey);
    final cachedAt = prefs.getInt(tyresCacheAtPrefsKey);
    final now = _clock();
    Map<String, TyreAllocation> cached = const {};
    if (cachedRaw != null) {
      try {
        cached = parseTyreAllocations(jsonDecode(cachedRaw));
      } catch (_) {}
    }
    if (cachedAt != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(cachedAt)) <
            kTyresCacheTtl) {
      return _remember(cached, DateTime.fromMillisecondsSinceEpoch(cachedAt));
    }

    try {
      final uri = Uri.parse(kTyresUrl);
      final response =
          await (_client != null ? _client.get(uri) : http.get(uri)).timeout(
            const Duration(seconds: 8),
          );
      if (response.statusCode != 200) {
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      final body = utf8.decode(response.bodyBytes);
      final parsed = parseTyreAllocations(jsonDecode(body));
      await prefs.setString(tyresCachePrefsKey, body);
      await prefs.setInt(tyresCacheAtPrefsKey, now.millisecondsSinceEpoch);
      return _remember(parsed, now);
    } catch (error, stackTrace) {
      reportSilentFailure('tyres fetch', error, stackTrace);
      // 실패는 캐시로 버티되 메모리엔 짧게만 둬서 다음 화면에서 다시 시도한다.
      _memory = cached;
      _memoryAt = now.subtract(kTyresCacheTtl - const Duration(minutes: 5));
      return cached;
    }
  }

  Map<String, TyreAllocation> _remember(
    Map<String, TyreAllocation> value,
    DateTime at,
  ) {
    _memory = value;
    _memoryAt = at;
    return value;
  }

  @visibleForTesting
  void resetForTest() {
    _memory = null;
    _memoryAt = null;
    _inFlight = null;
  }
}
