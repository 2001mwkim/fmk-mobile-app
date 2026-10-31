import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../models/live_positions.dart';
import 'live_session_service.dart';

/// 트랙맵 좌표 endpoint. live.json 과 같은 호스트(Cloudflare)의 `/positions.json`.
///
/// Vercel `/api/live` 폴백은 좌표를 중계하지 않고, 중계하더라도 엣지 요청
/// 한도(무료 100만/월)를 잡아먹으므로 **폴백을 두지 않는다**. live.json URL 이
/// `…/live.json` 형태가 아니면(예: Vercel 로 빌드) 지도 자체를 끈다(null).
String? livePositionsUrlFor(String liveJsonUrl) {
  const suffix = '/live.json';
  if (!liveJsonUrl.endsWith(suffix)) return null;
  return '${liveJsonUrl.substring(0, liveJsonUrl.length - suffix.length)}/positions.json';
}

/// 지도 카드가 떠 있는 동안만 3초마다 좌표를 받아 타임라인에 쌓는다.
///
/// 비용(디바이스당): 시간당 1,200건 × ≈0.9KB. 전부 Cloudflare 캐시 경로라
/// Vercel 0건, Railway 는 사용자 수와 무관하게 거점당 2초에 1번이다.
/// 백그라운드에선 멈춘다(CLAUDE.md '외부 비용 제약' — 포그라운드 한정 원칙).
class LivePositionsController with WidgetsBindingObserver {
  LivePositionsController({
    required this.delaySeconds,
    String? url,
    this.client,
    this.pollInterval = const Duration(seconds: 3),
  }) : url = url ?? livePositionsUrlFor(kLiveJsonUrl);

  /// 라이브 센터 영상 지연과 같은 값 — 서버가 같은 기준으로 창을 자른다.
  final int delaySeconds;
  final String? url;
  final http.Client? client;
  final Duration pollInterval;

  final LivePositionTimeline timeline = LivePositionTimeline();

  /// 재생 시각을 최신 데이터보다 이만큼 뒤에 둔다. 3초 폴링 + 엣지 캐시
  /// 최대 2초를 덮어 다음 묶음이 오기 전에 데이터가 바닥나지 않게 한다.
  static const int renderLagMs = 5000;

  Timer? _timer;
  bool _running = false;
  bool _inFlight = false;

  /// (수신 로컬 시각, 서버 최신 프레임 − 로컬 시각) 기록. 가장 신선한 응답을
  /// 기준으로 재생 시계를 잡는다 — 캐시로 오래된 응답이 섞여도 시계가
  /// 뒤로 튀지 않게 최근 30초의 최댓값을 쓴다.
  final List<(int, int)> _offsets = [];

  bool get isRunning => _running;

  /// [url] 이 null(지원 안 하는 live URL)이거나 빈 문자열(테스트·비활성)이면
  /// 아무 요청도 보내지 않는다.
  bool get _enabled => url != null && url!.isNotEmpty;

  void start() {
    if (_running || !_enabled) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(immediate: true);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void dispose() => stop();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed) {
      _schedule(immediate: true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    _timer = Timer(immediate ? Duration.zero : pollInterval, () async {
      await poll();
      if (_running) _schedule();
    });
  }

  @visibleForTesting
  Future<void> poll() async {
    final endpoint = url;
    if (endpoint == null || endpoint.isEmpty || _inFlight) return;
    _inFlight = true;
    final httpClient = client ?? http.Client();
    try {
      final base = Uri.parse(endpoint);
      final uri = delaySeconds > 0
          ? base.replace(
              queryParameters: {...base.queryParameters, 'delay': '$delaySeconds'},
            )
          : base;
      final response = await httpClient.get(uri).timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) return;
      final window = LivePositionsWindow.tryParse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (window == null) return;
      timeline.add(window);
      recordOffset(window.endMs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // 네트워크 실패는 다음 주기에 다시 시도한다. 지도는 마지막 위치에 멈춘다.
    } finally {
      _inFlight = false;
      if (client == null) httpClient.close();
    }
  }

  @visibleForTesting
  void recordOffset(int serverEndMs, int localMs) {
    _offsets.add((localMs, serverEndMs - localMs));
    _offsets.removeWhere((e) => localMs - e.$1 > 30000);
  }

  /// 지금 그릴 차량 위치(F1 원본 좌표). 데이터가 없으면 빈 맵.
  Map<String, Offset> positionsAt(DateTime now) {
    if (_offsets.isEmpty || timeline.isEmpty) return const {};
    var offset = _offsets.first.$2;
    for (final e in _offsets) {
      if (e.$2 > offset) offset = e.$2;
    }
    return timeline.sample(now.millisecondsSinceEpoch + offset - renderLagMs);
  }
}
