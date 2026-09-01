import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/races.dart';
import '../models/live_session.dart';
import 'live_session_service.dart';

/// 정상 수신 직후 이 기간까지는 stale 표시 없이 마지막 순위를 그대로 노출한다.
const Duration liveGracePeriod = Duration(minutes: 3);

/// 마지막 정상 수신 이후 이 기간이 지나면 라이브 박스를 내린다(default 로 전환).
const Duration liveStaleMaxAge = Duration(minutes: 10);

/// 진행 중 레이스/스프린트가 종료됐다는 단발성 신호를 확정하기 전 필요한 연속 수신 수.
/// collector 재연결 중 남은 상태값 하나로 '최종 결과'가 되는 것을 막는다.
const int endedConfirmationCount = 2;

/// live.json 을 주기적으로 폴링해 최신 [LiveSessionSnapshot] 을 제공한다.
///
/// - 리스너(화면)가 처음 붙으면 폴링을 시작하고, 모두 떨어지면 타이머를 정리한다.
/// - 정상 수신한 displayable 스냅샷을 [lastGoodLiveSnapshot] 으로 보관한다.
/// - fetch 실패 / 성공했지만 snapshot=null / 일시적 non-displayable 이 와도
///   [liveStaleMaxAge] 이내라면 마지막 정상 스냅샷을 계속 노출한다(라이브 중 순간
///   끊김에 박스가 깜빡이지 않게). [liveGracePeriod] 이후부터는 [isStale] 을 세워
///   UI 가 "업데이트 지연" 배지를 붙일 수 있게 한다.
/// - 단, 종료가 확정된(visibleUntil/스케줄 창이 지난 ended) 스냅샷이 오면 즉시 내린다.
/// - 라이브 센터용 [latestSessionSnapshot] 은 위 노출 기한과 별개로 마지막 세션을
///   계속 보존한다. 새 세션 스냅샷이 수신되면 그때 교체한다.
/// - [enabled] 가 false 면 폴링하지 않는다(위젯 테스트에서 네트워크 차단용).
class LiveSessionController extends ChangeNotifier with WidgetsBindingObserver {
  LiveSessionController(
    this._service, {
    this.gracePeriod = liveGracePeriod,
    this.staleMaxAge = liveStaleMaxAge,
    this.fastPollDuringRace = kLiveFastPollDuringRace,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LiveSessionService _service;
  final DateTime Function() _now;

  /// 폴링 주기(15~30초 권장).
  static const Duration pollInterval = Duration(seconds: 20);

  /// 레이스/스프린트 진행 중 주기. 순위가 가장 빠르게 바뀌는 구간이라 짧을수록
  /// 체감 품질이 좋다. [fastPollDuringRace] 가 true 일 때만 쓴다.
  ///
  /// 5초 = Cloudflare 엣지 캐시 TTL(collector 의 `s-maxage=5`)과 동일. 그보다
  /// 짧게 찔러도 엣지가 같은 응답을 돌려주므로 의미가 없고, 같으면 "새 데이터가
  /// 생길 때마다" 받는 최적점이다. origin(Railway) 부하는 캐시가 흡수해 사용자
  /// 수와 무관하게 분당 12회로 고정되고, Cloudflare 무료는 요청 수를 세지 않는다.
  static const Duration racePollInterval = Duration(seconds: 5);

  /// Vercel 폴백 경로([LiveSessionService.fallbackUrl])로 붙어 있을 때의 하한.
  /// 폴백은 Vercel 엣지 요청(무료 100만/월)을 쓰므로, DNS 장애가 레이스와 겹쳤을 때
  /// 5초 폴링이 그대로 Vercel 로 가면 한 레이스에 한도를 넘길 수 있다
  /// (5초 × 2시간 = 1,440건/사용자). 폴백 중에는 이 값보다 빠르게 폴링하지 않는다.
  static const Duration fallbackPollInterval = Duration(seconds: 10);

  /// 세션이 없을 때 주기. 앱이 포그라운드여도 이 간격으로만 네트워크를 쓴다.
  static const Duration idlePollInterval = Duration(minutes: 5);

  /// fetch 실패 직후 재시도 간격의 시작값. 실패에도 [idlePollInterval] 을 그대로
  /// 적용하면, DNS 장애처럼 금방 풀릴 수 있는 실패에도 화면이 5분간 비어 있다
  /// (2026-08-24 라이브 호스트 NXDOMAIN 사고). 연속 실패마다 2배씩 늘려
  /// [idlePollInterval] 에서 멈추므로 장기 장애의 요청 비용도 늘지 않는다.
  static const Duration retryPollInterval = Duration(seconds: 30);

  /// 레이스/스프린트 중 [racePollInterval] 로 당길지 여부. 기본값은 빌드 플래그
  /// [kLiveFastPollDuringRace] — 요청 수가 곧 비용이라 앞단 캐시를 갖추기 전엔
  /// 켜지 않는다. 테스트는 생성자로 직접 주입한다.
  final bool fastPollDuringRace;

  /// 타이머 tick 간격 — 실제 네트워크 호출은 [_pollDelay] 가 다시 걸러낸다.
  /// 가장 짧은 주기에 맞춰야 그 주기가 실현된다.
  Duration get _tickInterval =>
      fastPollDuringRace ? racePollInterval : pollInterval;

  /// 정상 수신 후 stale 로 표시하기 시작하는 기준.
  final Duration gracePeriod;

  /// 마지막 정상 수신 스냅샷을 유지할 최대 시간.
  final Duration staleMaxAge;

  /// 실제 폴링 활성화 여부. main() 에서 true 로 켠다(테스트에서는 기본 false).
  bool enabled = false;

  LiveSessionSnapshot? _snapshot;
  LiveSessionSnapshot? get snapshot => _snapshot;

  /// 라이브 센터가 표시할 가장 최근 세션. 종료 노출 기한이 지나도 유지하며,
  /// 다음 세션의 식별 가능한 스냅샷이 들어오면 즉시 새 세션으로 교체한다.
  LiveSessionSnapshot? _latestSessionSnapshot;
  LiveSessionSnapshot? get latestSessionSnapshot => _latestSessionSnapshot;

  DateTime? _latestSessionAt;

  bool _latestSessionIsStale = false;
  bool get latestSessionIsStale => _latestSessionIsStale;

  /// 마지막으로 정상 수신한(=displayable) 스냅샷. transient 실패 동안 재노출에 쓴다.
  LiveSessionSnapshot? _lastGoodSnapshot;
  LiveSessionSnapshot? get lastGoodLiveSnapshot => _lastGoodSnapshot;

  DateTime? _lastFetchedAt;
  DateTime? get lastFetchedAt => _lastFetchedAt;

  /// 마지막 정상 수신 시각.
  DateTime? _lastGoodAt;
  DateTime? get lastSuccessAt => _lastGoodAt;

  bool _isStale = false;
  bool get isStale => _isStale;

  /// 가장 최근에 끝난 세션의 최종 순위. 스냅샷이 내려가도(30분 노출 종료 등)
  /// 별도로 보존해 라이브 센터 "직전 세션 결과"가 계속 쓸 수 있게 한다.
  LiveLastSession? _lastSession;
  LiveLastSession? get lastSession => _lastSession;

  String? _pendingEndedSessionId;
  int _pendingEndedCount = 0;

  Timer? _timer;
  int _listeners = 0;
  DateTime? _nextNetworkPollAt;
  int _consecutiveFailures = 0;
  bool _isForeground = true;
  bool _lifecycleAttached = false;

  void attachLifecycle() {
    if (_lifecycleAttached) return;
    _lifecycleAttached = true;
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isForeground) return;
    _isForeground = foreground;
    if (foreground) {
      _nextNetworkPollAt = null;
      _start();
    } else {
      _stop();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    if (_listeners == 1) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners <= 0) _stop();
  }

  void _start() {
    if (!enabled || !_isForeground || _listeners <= 0 || _timer != null) {
      return;
    }
    unawaited(_poll());
    _timer = Timer.periodic(_tickInterval, (_) => unawaited(_poll()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final fetchedAt = _now();
    if (!_isForeground) return;
    final nextPollAt = _nextNetworkPollAt;
    if (nextPollAt != null && fetchedAt.isBefore(nextPollAt)) return;
    // 요청 중복을 막으려 먼저 잠가 두고, 수신 후 새 스냅샷 기준으로 다시 잡는다
    // (레이스 시작 직후 한 주기 늦게 빨라지는 것을 막는다).
    _nextNetworkPollAt = fetchedAt.add(_pollDelay(fetchedAt));
    _lastFetchedAt = fetchedAt;
    final result = await _service.fetchResult();
    _consecutiveFailures = result.succeeded ? 0 : _consecutiveFailures + 1;
    final received = result.succeeded ? result.snapshot : null;
    final fetched = _acceptSnapshot(received);

    var latestSessionChanged = false;
    if (fetched != null && _isSessionSnapshot(fetched)) {
      latestSessionChanged = _latestSessionSnapshot != fetched;
      _latestSessionSnapshot = fetched;
      _latestSessionAt = fetchedAt;
      _latestSessionIsStale = false;
    }

    // lastSession 은 표시 정책과 무관하게 항상 최신값을 보존한다.
    var lastSessionChanged = false;
    final fetchedLast = fetched?.lastSession;
    if (fetchedLast != null && fetchedLast.endedAt != _lastSession?.endedAt) {
      _lastSession = fetchedLast;
      lastSessionChanged = true;
      // snapshot=null 인 응답으로 콜드 스타트한 경우에도 직전 순위는 라이브
      // 센터 본문에서 볼 수 있게 한다. 완전한 스냅샷이 있으면 그쪽을 유지한다.
      if (_latestSessionSnapshot == null) {
        _latestSessionSnapshot = _snapshotFromLastSession(fetchedLast);
        _latestSessionAt = fetchedAt;
        _latestSessionIsStale = false;
        latestSessionChanged = true;
      }
    }

    if (!latestSessionChanged &&
        _latestSessionSnapshot?.status == LiveSessionStatus.live &&
        _latestSessionAt != null) {
      final stale = fetchedAt.difference(_latestSessionAt!) > gracePeriod;
      if (stale != _latestSessionIsStale) {
        _latestSessionIsStale = stale;
        latestSessionChanged = true;
      }
    }

    final LiveSessionSnapshot? next;
    final bool nextIsStale;

    if (fetched != null && isLiveSnapshotDisplayable(fetched, fetchedAt)) {
      // 정상 수신: 최신 스냅샷을 노출하고 lastGood 갱신.
      next = fetched;
      nextIsStale = false;
      _lastGoodSnapshot = fetched;
      _lastGoodAt = fetchedAt;
    } else if (_isConfirmedEnd(result.succeeded, fetched, fetchedAt)) {
      // 종료 확정(visibleUntil/스케줄 창이 지난 ended): 즉시 내린다.
      next = null;
      nextIsStale = false;
      _lastGoodSnapshot = null;
      _lastGoodAt = null;
    } else if (_canKeepLastGood(fetchedAt)) {
      // 일시적 실패 / null / non-displayable: 마지막 정상 스냅샷 유지.
      next = _lastGoodSnapshot;
      nextIsStale = _staleAge(fetchedAt) > gracePeriod;
    } else {
      // staleMaxAge 초과: 라이브 박스를 내린다.
      next = null;
      nextIsStale = false;
      _lastGoodSnapshot = null;
      _lastGoodAt = null;
    }

    // 방금 받은 스냅샷 기준으로 다음 호출 시각을 다시 잡는다. 레이스가 시작되면
    // 한 주기 기다리지 않고 곧바로 빠른 주기로 넘어간다.
    _nextNetworkPollAt = fetchedAt.add(_nextDelayFor(next, fetchedAt));

    if (next == _snapshot &&
        nextIsStale == _isStale &&
        !lastSessionChanged &&
        !latestSessionChanged) {
      return;
    }
    _snapshot = next;
    _isStale = nextIsStale;
    notifyListeners();
  }

  /// 종료가 "확정"된 응답인가. fetch 성공 + ended 스냅샷 + 노출 창이 지난 경우만
  /// 확정 종료로 보고 즉시 내린다. null/inactive/실패는 transient 로 취급한다.
  bool _isConfirmedEnd(
    bool succeeded,
    LiveSessionSnapshot? fetched,
    DateTime now,
  ) {
    if (!succeeded || fetched == null) return false;
    return fetched.status == LiveSessionStatus.ended &&
        !isLiveSnapshotDisplayable(fetched, now);
  }

  bool _canKeepLastGood(DateTime now) {
    final at = _lastGoodAt;
    if (_lastGoodSnapshot == null || at == null) return false;
    return now.difference(at) <= staleMaxAge;
  }

  Duration _staleAge(DateTime now) {
    final at = _lastGoodAt;
    return at == null ? Duration.zero : now.difference(at);
  }

  /// 라이브였던 레이스/스프린트의 중간 종료 신호는 두 번 연속 확인한다.
  /// 완주 랩에 도달한 경우는 명백한 종료 근거가 있으므로 바로 수용한다.
  LiveSessionSnapshot? _acceptSnapshot(LiveSessionSnapshot? received) {
    if (!_requiresEndedConfirmation(received)) {
      _clearPendingEnded();
      return received;
    }

    final id = _sessionIdentity(received!);
    if (id == null) return received;
    if (id == _pendingEndedSessionId) {
      _pendingEndedCount++;
    } else {
      _pendingEndedSessionId = id;
      _pendingEndedCount = 1;
    }

    if (_pendingEndedCount >= endedConfirmationCount) {
      _clearPendingEnded();
      return received;
    }
    return null;
  }

  bool _requiresEndedConfirmation(LiveSessionSnapshot? received) {
    if (received == null ||
        received.status != LiveSessionStatus.ended ||
        !received.isRaceOrSprint) {
      return false;
    }
    final previous = _latestSessionSnapshot;
    if (previous == null ||
        previous.status != LiveSessionStatus.live ||
        !_sameSession(previous, received)) {
      return false;
    }
    final currentLap = received.currentLap;
    final totalLaps = received.totalLaps;
    return currentLap == null || totalLaps == null || currentLap < totalLaps;
  }

  bool _sameSession(LiveSessionSnapshot a, LiveSessionSnapshot b) {
    final aId = _sessionIdentity(a);
    final bId = _sessionIdentity(b);
    return aId != null && aId == bId;
  }

  String? _sessionIdentity(LiveSessionSnapshot value) {
    final key = value.sessionKey?.trim();
    if (key != null && key.isNotEmpty) return 'key:$key';
    final race = (value.raceId ?? value.raceName)?.trim();
    final session = (value.sessionName ?? value.sessionType)?.trim();
    if (race == null || race.isEmpty || session == null || session.isEmpty) {
      return null;
    }
    return 'session:$race/$session';
  }

  void _clearPendingEnded() {
    _pendingEndedSessionId = null;
    _pendingEndedCount = 0;
  }

  /// top-level wrapper만 잘못 스냅샷처럼 파싱된 빈 inactive 값은 제외한다.
  /// inactive 여도 세션 식별자가 있으면 시작 직전 준비 스냅샷으로 인정한다.
  bool _isSessionSnapshot(LiveSessionSnapshot value) {
    final hasIdentity =
        (value.raceId?.isNotEmpty ?? false) ||
        (value.raceName?.isNotEmpty ?? false) ||
        (value.sessionKey?.isNotEmpty ?? false) ||
        (value.sessionType?.isNotEmpty ?? false) ||
        (value.sessionName?.isNotEmpty ?? false);
    final hasDetails =
        value.classification.isNotEmpty ||
        value.topThree.isNotEmpty ||
        value.weather != null ||
        value.raceControlMessages.isNotEmpty;
    return hasIdentity || hasDetails;
  }

  LiveSessionSnapshot _snapshotFromLastSession(LiveLastSession last) {
    final classification = [...last.classification]
      ..sort((a, b) => a.position.compareTo(b.position));
    return LiveSessionSnapshot(
      status: LiveSessionStatus.ended,
      updatedAt: last.endedAt?.toIso8601String() ?? '',
      raceId: last.raceId,
      raceName: last.raceName,
      sessionType: last.sessionType,
      sessionName: last.sessionName,
      topThree: classification.take(3).toList(),
      classification: classification,
      endedAt: last.endedAt,
    );
  }

  /// 다음 네트워크 호출 예정 시각. 폴링 주기가 세션 종류에 맞게 잡히는지
  /// 검증하는 용도(타이머를 돌리지 않고도 확인할 수 있다).
  @visibleForTesting
  DateTime? get nextNetworkPollAt => _nextNetworkPollAt;

  /// 디버그 진단용 — 현재 1순위 endpoint(폴백 사용 여부 확인).
  String get activeUrl => _service.activeUrl;

  /// 마지막 성공 endpoint 가 1순위(Cloudflare)가 아닌 폴백(Vercel)인지.
  bool get _onFallback => _service.activeUrl != _service.url;

  /// 디버그 진단용 — 연속 fetch 실패 횟수(백오프 단계 확인).
  int get consecutiveFailures => _consecutiveFailures;

  /// 외부에서 즉시 1회 갱신이 필요할 때.
  Future<void> refresh() {
    _nextNetworkPollAt = null;
    return _poll();
  }

  Duration _pollDelay(DateTime now) => _nextDelayFor(_snapshot, now);

  /// 스케줄 기준 주기와 실패 백오프 중 **짧은 쪽**. 레이스 중(10초)에는 실패해도
  /// 백오프로 느려지지 않고, 세션이 없을 때(5분)는 실패 직후 빠르게 재시도한다.
  Duration _nextDelayFor(LiveSessionSnapshot? current, DateTime now) {
    final scheduled = _pollDelayFor(current, now);
    if (_consecutiveFailures == 0) return scheduled;
    final backoff = _failureDelay();
    return backoff < scheduled ? backoff : scheduled;
  }

  /// 30초 → 60초 → 120초 … [idlePollInterval] 상한.
  Duration _failureDelay() {
    final steps = (_consecutiveFailures - 1).clamp(0, 4);
    final backoff = retryPollInterval * (1 << steps);
    return backoff > idlePollInterval ? idlePollInterval : backoff;
  }

  Duration _pollDelayFor(LiveSessionSnapshot? current, DateTime now) {
    if (current != null && isLiveSnapshotSessionActive(current, now)) {
      // 레이스/스프린트만 당긴다. 연습/퀄리는 랩타임 갱신이 드물어 20초로 충분.
      final base = fastPollDuringRace && current.isRaceOrSprint
          ? racePollInterval
          : pollInterval;
      // Vercel 폴백 중에는 [fallbackPollInterval] 아래로 내려가지 않는다.
      return _onFallback && base < fallbackPollInterval
          ? fallbackPollInterval
          : base;
    }
    for (final race in races) {
      if (race.isCancelled) continue;
      for (final session in race.sessions) {
        final start = getSessionDate(
          race,
          session,
        ).subtract(const Duration(minutes: 30));
        final end = getSessionEndDate(
          race,
          session,
        ).add(const Duration(minutes: 90));
        if (!now.isBefore(start) && !now.isAfter(end)) return pollInterval;
      }
    }
    return idlePollInterval;
  }

  @override
  void dispose() {
    if (_lifecycleAttached) WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }
}

/// 앱 전역 컨트롤러(단일 타이머). main() 에서 enabled = true 로 켠다.
final LiveSessionController liveSessionController = LiveSessionController(
  LiveSessionService(),
);
