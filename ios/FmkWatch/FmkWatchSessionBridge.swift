import Foundation
import WatchConnectivity
import WidgetKit

// 아이폰(Runner/FmkWatchSync.swift)이 보낸 App Group 사본을 워치 쪽
// App Group UserDefaults 에 같은 키로 저장한다. 그러면 FmkPayloadStore.swift
// 의 FmkPayload.load()/standings()/myDriver() 가 워치 앱·컴플리케이션
// 양쪽에서 수정 없이 동작한다. 저장 후 컴플리케이션 타임라인을 다시 그린다.
final class FmkWatchSessionBridge: NSObject, WCSessionDelegate, ObservableObject {
  static let shared = FmkWatchSessionBridge()

  /// 마지막 수신 시각 — 뷰가 이 값을 관찰해 새 데이터를 다시 읽는다.
  @Published private(set) var lastReceived: Date? = loadSyncedAt()

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    if session.activationState != .activated { session.activate() }
  }

  /// 아이폰 앱이 한 번이라도 데이터를 보냈는지(최초 설치 안내용).
  var hasData: Bool { !FmkPayload.load().isEmpty }

  private static func loadSyncedAt() -> Date? {
    let seconds = UserDefaults(suiteName: fmkAppGroupId)?.double(forKey: "fmkSyncedAt") ?? 0
    return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
  }

  private func store(_ context: [String: Any]) {
    guard let defaults = UserDefaults(suiteName: fmkAppGroupId) else { return }
    for (key, value) in context { defaults.set(value, forKey: key) }
    defaults.synchronize()
    WidgetCenter.shared.reloadAllTimelines()
    DispatchQueue.main.async { self.lastReceived = Date() }
  }

  // MARK: WCSessionDelegate
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    // 활성화 시점에 이미 도착해 있던 최신 컨텍스트를 반영한다.
    let context = session.receivedApplicationContext
    if !context.isEmpty { store(context) }
  }

  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    store(applicationContext)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    // transferCurrentComplicationUserInfo 도 이 경로로 온다.
    store(userInfo)
  }
}
