import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Live Activity 채널(fmk/live_activity) — Flutter 라이브 폴링과 연동.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FmkLiveActivity") {
      FmkLiveActivityManager.shared.install(messenger: registrar.messenger())
    }
    // 애플워치 동기화 채널(fmk/watch) — 브리지 저장 후 App Group 을 워치로 전송.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FmkWatchSync") {
      FmkWatchSync.shared.install(messenger: registrar.messenger())
    }
  }
}
