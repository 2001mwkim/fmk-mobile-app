import Flutter
import Foundation
import WatchConnectivity

// 아이폰 → 애플워치 데이터 동기화.
//
// 왜 필요한가: App Group UserDefaults 는 아이폰 앱 ↔ iOS 위젯 사이에서만
// 공유되고 워치와는 공유되지 않는다. 그래서 브리지(fmk_home_widget_bridge.dart)가
// App Group 에 저장을 마친 뒤 MethodChannel `fmk/watch` 의 `sync` 를 호출하면,
// 여기서 App Group 의 전체 키/값을 읽어 WCSession 으로 워치에 밀어준다.
// 워치 앱(FmkWatchSessionBridge)은 받은 값을 워치 쪽 App Group 에 같은
// 키로 저장하므로 FmkPayloadStore.swift 가 양쪽에서 그대로 동작한다.
//
// 전송 방식 2가지(둘 다 보낸다):
// - updateApplicationContext: 최신 1건만 유지, 워치 앱이 다음에 깨어날 때 전달
// - transferCurrentComplicationUserInfo: 컴플리케이션이 설치된 경우 워치 앱을
//   백그라운드로 깨워 즉시 전달(하루 50회 예산 — 그래서 변경 없으면 스킵)
final class FmkWatchSync: NSObject, WCSessionDelegate {
  static let shared = FmkWatchSync()
  private let appGroupId = "group.kr.formulamagazine.fmk"
  private var lastSentHash: Int = 0

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "fmk/watch", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "sync":
        self?.sync()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    activate()
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    if session.activationState != .activated { session.activate() }
  }

  /// App Group 전체를 워치로 전송. 값이 지난번과 같으면 전송하지 않는다.
  func sync() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired,
      session.isWatchAppInstalled
    else { return }
    guard let store = UserDefaults(suiteName: appGroupId) else { return }
    // property-list 값만 전송 가능 — 브리지는 String/Int 만 저장한다.
    var payload: [String: Any] = [:]
    for (key, value) in store.dictionaryRepresentation() {
      if value is String || value is Int || value is Double || value is Bool {
        payload[key] = value
      }
    }
    payload["fmkSyncedAt"] = Date().timeIntervalSince1970
    var hasher = Hasher()
    for key in payload.keys.sorted() where key != "fmkSyncedAt" {
      hasher.combine(key)
      hasher.combine(String(describing: payload[key]!))
    }
    let hash = hasher.finalize()
    guard hash != lastSentHash else { return }
    lastSentHash = hash

    try? session.updateApplicationContext(payload)
    if session.isComplicationEnabled {
      session.transferCurrentComplicationUserInfo(payload)
    }
  }

  // MARK: WCSessionDelegate
  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    if activationState == .activated { sync() }
  }
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
  func sessionWatchStateDidChange(_ session: WCSession) {
    // 워치 앱 설치/컴플리케이션 추가 직후 최신 데이터를 바로 보낸다.
    lastSentHash = 0
    sync()
  }
}
