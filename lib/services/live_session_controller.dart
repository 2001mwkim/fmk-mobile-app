import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/live_session.dart';
import 'live_session_service.dart';

/// 정상 수신 직후 이 기간까지는 stale 표시 없이 마지막 순위를 그대로 노출한다.
const Duration liveGracePeriod = Duration(minutes: 3);

/// 마지막 정상 수신 이후 이 기간이 지나면 라이브 박스를 내린다(default 로 전환).
const Duration liveStaleMaxAge = Duration(minutes: 10);

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
class LiveSessionController extends ChangeNotifier {
  LiveSessionController(
    this._service, {
    this.gracePeriod = liveGracePeriod,
    this.staleMaxAge = liveStaleMaxAge,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LiveSessionService _service;
  final DateTime Function() _now;

  /// 폴링 주기(15~30초 권장).
  static const Duration pollInterval = Duration(seconds: 20);

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

  Timer? _timer;
  int _listeners = 0;

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
    if (!enabled || _timer != null) return;
    unawaited(_poll());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final fetchedAt = _now();
    _lastFetchedAt = fetchedAt;
    final result = await _service.fetchResult();
    final fetched = result.succeeded ? result.snapshot : null;

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

  /// 외부에서 즉시 1회 갱신이 필요할 때.
  Future<void> refresh() => _poll();
}

/// 앱 전역 컨트롤러(단일 타이머). main() 에서 enabled = true 로 켠다.
final LiveSessionController liveSessionController = LiveSessionController(
  const LiveSessionService(),
);
