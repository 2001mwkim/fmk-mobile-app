import SwiftUI
import WatchKit

// 애플워치 앱 진입점. Flutter 는 watchOS 를 지원하지 않으므로 워치 부분은
// 순수 SwiftUI 다. 데이터는 아이폰 앱이 WatchConnectivity 로 밀어준
// 위젯 페이로드(FmkPayloadStore.swift 와 동일 키)를 워치 App Group 에서 읽는다.
@main
struct FmkWatchApp: App {
  @WKApplicationDelegateAdaptor(FmkWatchAppDelegate.self) private var delegate

  var body: some Scene {
    WindowGroup {
      FmkWatchRootView()
    }
  }
}

/// WCSession 은 앱 시작 시 한 번 활성화해 둬야 백그라운드 전달을 받는다.
final class FmkWatchAppDelegate: NSObject, WKApplicationDelegate {
  func applicationDidFinishLaunching() {
    FmkWatchSessionBridge.shared.activate()
  }
}
