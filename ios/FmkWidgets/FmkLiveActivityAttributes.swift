import Foundation

#if canImport(ActivityKit)
  import ActivityKit

  // 라이브 세션 Live Activity 의 데이터 계약.
  //
  // ContentState 필드는 collector 의 APNs content-state JSON 과 문자열로
  // 수동 동기화된다(fmk-f1-calendar scripts/live-activity-push.ts) — 한쪽을
  // 바꾸면 반드시 함께 수정할 것. 평평한 구조(중첩 배열 없음)를 유지해
  // 서버 페이로드 작성 실수를 줄인다.
  //
  // 이 파일은 Runner 와 FmkWidgets 양쪽 타깃에 포함된다(Activity 시작은 앱,
  // UI 렌더는 익스텐션 — 동일 타입이어야 매칭된다).
  @available(iOS 16.1, *)
  struct FmkLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      var badge: String  // "LIVE" | "RESULT"
      var gpName: String
      var sessionName: String  // 표시용 세션명(예: "퀄리파잉")
      var lapCurrent: Int  // 레이스/스프린트 외에는 0
      var lapTotal: Int
      var p1Name: String
      var p1Time: String
      var p2Name: String
      var p2Time: String
      var p3Name: String
      var p3Time: String
      var updatedAt: String  // "HH:mm" KST — 스테일 판단용 표시 문자열
    }

    // 고정 속성: 활동 수명 동안 불변.
    var raceId: String
  }
#endif
