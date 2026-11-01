import 'dart:math';

import 'package:sentry_flutter/sentry_flutter.dart';

/// 조용히 폴백하는 catch 블록·"200 인데 쓸 수 없는 응답" 을 Sentry 에 남긴다.
///
/// 앱은 네트워크/파싱 실패를 정적 데이터·캐시로 감춰 화면이 죽지 않게 하는데,
/// 그 덕에 서버 장애가 사용자에게도 개발자에게도 안 보였다 — 2026-10-31
/// Vercel `/api/standings` 가 빈 배열을 200 으로 내려 앱이 몇 달 묵은 정적
/// 순위로 폴백하던 사고가 그 예다. 그래서 두 등급으로 나눠 남긴다:
///
/// - 네트워크성 실패(타임아웃·연결 끊김 등 — 오프라인 사용자에겐 일상)는
///   breadcrumb 만 남긴다. 이벤트를 만들지 않아 쿼터를 쓰지 않고, 다음 실제
///   크래시 리포트에 맥락으로 붙는다.
/// - 데이터성 실패(파싱 예외, 200 인데 내용이 비었거나 깨짐)는 서버 쪽 사고일
///   가능성이 높아 warning 이벤트로 보낸다. 모든 디바이스가 같은 응답을 받으므로
///   [where] 마다 프로세스당 1회 + [kSilentFailureSampleRate] 표본만 보내 쿼터
///   폭주를 막는다(Sentry 무료 쿼터는 월 5천 이벤트 — 사고 하나가 전 디바이스에서
///   동시에 터져도 신호만 받으면 충분하다).
///
/// Sentry 가 초기화되지 않은 debug/테스트 환경에서는 Sentry 정적 API 가
/// no-op 이라 그대로 호출해도 안전하다.
void reportSilentFailure(
  String where,
  Object error, [
  StackTrace? stackTrace,
]) {
  if (_isDataError(error)) {
    if (!_shouldSend(where)) return;
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = SentryLevel.warning;
        scope.setTag('silent_failure', where);
      },
    );
    return;
  }
  Sentry.addBreadcrumb(
    Breadcrumb(
      category: 'silent_failure',
      message: '$where: ${error.runtimeType}',
      level: SentryLevel.info,
    ),
  );
}

/// 예외 없이 "200 인데 쓸 수 없는 응답"(빈 배열·필수 필드 누락 등)을 받은 경우.
/// 서버 쪽 사고 신호라 warning 이벤트로 보낸다([where] 마다 프로세스당 1회).
void reportDataAnomaly(String where, String message) {
  if (!_shouldSend(where)) return;
  Sentry.captureMessage(
    '$where: $message',
    level: SentryLevel.warning,
    withScope: (scope) => scope.setTag('data_anomaly', where),
  );
}

/// HTTP 상태 코드가 200 이 아닌 응답. 일시적 5xx·4xx 는 흔하므로 breadcrumb.
void reportHttpStatus(String where, int statusCode) {
  Sentry.addBreadcrumb(
    Breadcrumb(
      category: 'silent_failure',
      message: '$where: HTTP $statusCode',
      level: SentryLevel.info,
    ),
  );
}

/// 데이터성 경고 이벤트의 표본 비율(디바이스·프로세스 단위로 한 번 추첨).
const double kSilentFailureSampleRate = 0.1;

final Set<String> _reportedOnce = <String>{};
final Random _random = Random();

bool _shouldSend(String where) {
  if (!_reportedOnce.add(where)) return false;
  return _random.nextDouble() < kSilentFailureSampleRate;
}

/// 파싱·타입 오류처럼 "서버가 이상한 걸 줬다" 쪽 예외. 그 밖의 예외
/// (TimeoutException·ClientException·SocketException 등)는 네트워크성으로 본다.
/// dart:io 를 import 하지 않으려고(웹 빌드 호환) 데이터성 쪽을 열거한다.
bool _isDataError(Object error) =>
    error is FormatException ||
    error is TypeError ||
    error is ArgumentError ||
    error is StateError ||
    error is NoSuchMethodError;
