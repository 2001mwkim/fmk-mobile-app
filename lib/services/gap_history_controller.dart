import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../models/gap_history.dart';
import 'error_reporting.dart';
import 'live_session_service.dart';

/// 갭 추이 endpoint. live.json 과 같은 호스트(Cloudflare)의 `/gap-history.json`.
/// 트랙맵 좌표와 같은 이유로 Vercel 폴백을 두지 않는다 — live URL 이
/// `…/live.json` 형태가 아니면 null(카드가 요청을 보내지 않는다).
String? liveGapHistoryUrlFor(String liveJsonUrl) {
  const suffix = '/live.json';
  if (!liveJsonUrl.endsWith(suffix)) return null;
  return '${liveJsonUrl.substring(0, liveJsonUrl.length - suffix.length)}/gap-history.json';
}

/// 갭 그래프 카드가 떠 있고 앱이 포그라운드일 때만 30초마다 받는다.
///
/// 비용(디바이스당): 시간당 120건, 전부 Cloudflare(s-maxage=10) — Vercel 0건.
/// 랩은 80초 남짓마다 하나씩 늘어서 30초면 충분히 따라간다.
class GapHistoryController extends ChangeNotifier with WidgetsBindingObserver {
  GapHistoryController({
    required this.delaySeconds,
    String? url,
    this.client,
    this.pollInterval = const Duration(seconds: 30),
  }) : url = url ?? liveGapHistoryUrlFor(kLiveJsonUrl);

  /// 라이브 센터 영상 지연과 같은 값.
  final int delaySeconds;
  final String? url;
  final http.Client? client;
  final Duration pollInterval;

  GapHistory _history = GapHistory.empty;
  GapHistory get history => _history;

  Timer? _timer;
  bool _running = false;
  bool _inFlight = false;
  bool _disposed = false;

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

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }

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
              queryParameters: {
                ...base.queryParameters,
                'delay': '$delaySeconds',
              },
            )
          : base;
      final response = await httpClient.get(uri).timeout(kLiveFetchTimeout);
      if (response.statusCode != 200) {
        reportHttpStatus('gap_history', response.statusCode);
        return;
      }
      final parsed = GapHistory.tryParse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (parsed == null || _disposed) return;
      _history = parsed;
      notifyListeners();
    } catch (error, stackTrace) {
      // 다음 주기에 다시 시도한다. 그래프는 마지막 데이터로 남는다.
      reportSilentFailure('gap_history', error, stackTrace);
    } finally {
      _inFlight = false;
      if (client == null) httpClient.close();
    }
  }
}
