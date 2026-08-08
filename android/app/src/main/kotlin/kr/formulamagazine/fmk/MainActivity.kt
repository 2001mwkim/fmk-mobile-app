package kr.formulamagazine.fmk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

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
