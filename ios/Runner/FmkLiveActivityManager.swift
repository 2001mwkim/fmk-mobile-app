import Flutter
import Foundation

#if canImport(ActivityKit)
  import ActivityKit
#endif

// Flutter(라이브 폴링) ↔ ActivityKit 브리지.
//
// 채널 계약(lib/services/fmk_live_activity_bridge.dart 와 수동 동기화):
// - configure {registerUrl}: 토큰 등록 엔드포인트 설정 + push-to-start 토큰 관찰 시작
// - sync {raceId, badge, gpName, sessionName, lapCurrent, lapTotal,
//         p1Name...p3Time, updatedAt}: 활동 시작 또는 갱신
// - end {}: 활동 종료(최종 상태 유지 후 시스템 기본 시점에 제거)
//
// 푸시 갱신(방식2): 활동/push-to-start 토큰을 collector 에 등록하면
// collector 가 APNs 로 직접 start/update/end 를 보낸다. 앱이 실행 중일 때는
// sync 로컬 갱신도 함께 동작(중복 무해 — 같은 상태 덮어쓰기).
class FmkLiveActivityManager: NSObject {
  static let shared = FmkLiveActivityManager()

  private var registerUrl: URL?
  private var observersInstalled = false

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fmk/live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "configure":
        if let args = call.arguments as? [String: Any?],
          let raw = args["registerUrl"] as? String
        {
          self.registerUrl = URL(string: raw)
        }
        self.installTokenObserversIfNeeded()
        result(true)
      case "sync":
        if #available(iOS 16.1, *), let args = call.arguments as? [String: Any?] {
          self.sync(args: args)
        }
        result(true)
      case "end":
        if #available(iOS 16.1, *) {
          self.endAll()
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // ── ActivityKit ──

  @available(iOS 16.1, *)
  private func contentState(from args: [String: Any?]) -> FmkLiveActivityAttributes.ContentState {
    func str(_ key: String) -> String { (args[key] as? String) ?? "" }
    func num(_ key: String) -> Int { (args[key] as? Int) ?? 0 }
    return FmkLiveActivityAttributes.ContentState(
      badge: str("badge").isEmpty ? "LIVE" : str("badge"),
      gpName: str("gpName"),
      sessionName: str("sessionName"),
      lapCurrent: num("lapCurrent"),
      lapTotal: num("lapTotal"),
      p1Name: str("p1Name"), p1Time: str("p1Time"),
      p1Code: str("p1Code").isEmpty ? nil : str("p1Code"),
      p2Name: str("p2Name"), p2Time: str("p2Time"),
      p3Name: str("p3Name"), p3Time: str("p3Time"),
      updatedAt: str("updatedAt")
    )
  }

  @available(iOS 16.1, *)
  private func sync(args: [String: Any?]) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let raceId = (args["raceId"] as? String) ?? ""
    let state = contentState(from: args)

    if let activity = Activity<FmkLiveActivityAttributes>.activities.first {
      Task { await activity.update(using: state) }
      return
    }

    do {
      let activity = try request(raceId: raceId, state: state, pushType: .token)
      observePushToken(of: activity)
    } catch {
      // 푸시 entitlement 미승인 환경 등 — 로컬 전용(앱 실행 중 갱신)으로 폴백.
      NSLog("FmkLiveActivity push-token start failed, falling back to local: \(error)")
      do {
        _ = try request(raceId: raceId, state: state, pushType: nil)
      } catch {
        // 사용자 비활성화/빈도 제한 등 — 라이브 기능 자체에는 영향 없음.
        NSLog("FmkLiveActivity start failed: \(error)")
      }
    }
  }

  @available(iOS 16.1, *)
  private func request(
    raceId: String,
    state: FmkLiveActivityAttributes.ContentState,
    pushType: PushType?
  ) throws -> Activity<FmkLiveActivityAttributes> {
    if #available(iOS 16.2, *) {
      return try Activity.request(
        attributes: FmkLiveActivityAttributes(raceId: raceId),
        content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)),
        pushType: pushType
      )
    }
    return try Activity.request(
      attributes: FmkLiveActivityAttributes(raceId: raceId),
      contentState: state,
      pushType: pushType
    )
  }

  @available(iOS 16.1, *)
  private func endAll() {
    Task {
      for activity in Activity<FmkLiveActivityAttributes>.activities {
        // 최종 상태를 유지한 채 종료 — 시스템 기본 제거 정책 사용.
        await activity.end(using: activity.contentState, dismissalPolicy: .default)
      }
    }
  }

  // ── 토큰 등록 ──

  private func installTokenObserversIfNeeded() {
    guard !observersInstalled else { return }
    observersInstalled = true

    if #available(iOS 16.1, *) {
      // 앱 재시작 후 기존/푸시 시작 활동의 토큰도 놓치지 않게 전체 관찰.
      Task {
        for await activity in Activity<FmkLiveActivityAttributes>.activityUpdates {
          self.observePushToken(of: activity)
        }
      }
      for activity in Activity<FmkLiveActivityAttributes>.activities {
        observePushToken(of: activity)
      }
    }

    if #available(iOS 17.2, *) {
      // push-to-start: collector 가 앱 실행 없이도 활동을 시작할 수 있는 토큰.
      Task {
        for await token in Activity<FmkLiveActivityAttributes>.pushToStartTokenUpdates {
          self.register(kind: "push-to-start", token: token, raceId: nil)
        }
      }
    }
  }

  @available(iOS 16.1, *)
  private func observePushToken(of activity: Activity<FmkLiveActivityAttributes>) {
    Task {
      for await token in activity.pushTokenUpdates {
        self.register(kind: "activity", token: token, raceId: activity.attributes.raceId)
      }
    }
  }

  private func register(kind: String, token: Data, raceId: String?) {
    guard let url = registerUrl else { return }
    let hex = token.map { String(format: "%02x", $0) }.joined()
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    var body: [String: Any] = [
      "kind": kind,
      "token": hex,
      // 디버그 빌드는 APNs sandbox 토큰 — collector 가 환경을 구분한다.
      "environment": isDebugBuild ? "sandbox" : "production",
    ]
    if let raceId { body["raceId"] = raceId }
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request).resume()
  }

  private var isDebugBuild: Bool {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }
}
