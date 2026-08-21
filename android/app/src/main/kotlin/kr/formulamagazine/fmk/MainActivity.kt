package kr.formulamagazine.fmk

import android.content.pm.ActivityInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // 폰은 매니페스트에서 portrait 고정(웹 UI 이식 디자인). 태블릿(sw≥600dp)만
    // 전방향 허용. screenOrientation 은 매니페스트 리소스로 설정별 분기가 안 되므로
    // (릴리스 lint: ManifestResource) 런타임에서 처리한다. smallestScreenWidthDp 는
    // 기기 고정값이라 onCreate 1회 판정으로 충분하다.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (resources.configuration.smallestScreenWidthDp >= 600) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_FULL_USER
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 라이브 액티비티(Now Bar) 제어 채널. Dart(LiveActivityBridge)가
        // 라이브 세션 시작/종료에 맞춰 포그라운드 서비스를 켜고 끈다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ACTIVITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val url = call.argument<String>("liveJsonUrl")
                        if (url.isNullOrBlank()) {
                            result.error("no_url", "liveJsonUrl required", null)
                        } else {
                            LiveActivityService.start(applicationContext, url)
                            result.success(true)
                        }
                    }
                    "stop" -> {
                        LiveActivityService.stop(applicationContext)
                        result.success(true)
                    }
                    "startDemo" -> {
                        LiveActivityService.startDemo(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val LIVE_ACTIVITY_CHANNEL = "fmk/live_activity"
    }
}
