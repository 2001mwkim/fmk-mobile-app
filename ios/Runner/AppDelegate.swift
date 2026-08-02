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
  }
}
