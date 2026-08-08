package kr.formulamagazine.fmk

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 라이브 세션(레이스/스프린트) 동안 Android 16 Live Update(삼성 One UI Now Bar)
 * 알림을 앱이 꺼져 있어도 갱신하는 포그라운드 서비스.
 *
 * - Dart(LiveActivityBridge)가 세션이 라이브가 되면 START, 아니면 STOP 을 보낸다.
 * - 앱이 종료돼 Dart 가 살아 있지 않아도 이 서비스가 [liveJsonUrl] 을 직접
 *   폴링하며 알림을 갱신하고, 스냅샷이 더 이상 "라이브 레이스/스프린트"가
 *   아니면 스스로 종료한다.
 * - ProgressStyle(랩 진행 바)은 Android 16(SDK 36)+ 에서 Now Bar/잠금화면에
 *   승격되고, 그 미만에서는 일반 상시 알림으로 자연스럽게 폴백된다
 *   (NotificationCompat 이 버전 호환을 처리).
 */
class LiveActivityService : Service() {

    companion object {
        const val ACTION_START = "kr.formulamagazine.fmk.LIVE_ACTIVITY_START"
        const val ACTION_STOP = "kr.formulamagazine.fmk.LIVE_ACTIVITY_STOP"
        const val EXTRA_LIVE_JSON_URL = "liveJsonUrl"
        // 개발 검증용: 폴링 없이 정적 데이터로 알림을 띄운다(실제 라이브 세션 없이
        // Now Bar 렌더링 확인). 디버그 빌드의 설정 화면 버튼에서만 호출된다.
        const val EXTRA_DEMO = "demo"

        private const val CHANNEL_ID = "fmk_live_activity"
        private const val NOTIFICATION_ID = 424242
        private const val POLL_SECONDS = 20L
        private const val TAG = "FmkLiveActivity"

        // F1 레드 계열 액센트(노란색 금지 규칙 — 강조도 레드).
        private const val ACCENT = 0xFFE10600.toInt()
        private const val TRACK = 0xFF3A3A3A.toInt()

        fun start(context: Context, liveJsonUrl: String) {
            val intent = Intent(context, LiveActivityService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_LIVE_JSON_URL, liveJsonUrl)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, LiveActivityService::class.java).apply {
                action = ACTION_STOP
            }
            // onStartCommand 를 거쳐 정리 후 종료(직접 stopService 보다 순서 명확).
            context.startService(intent)
        }

        /** 개발 검증용 데모 시작(정적 데이터, 폴링/자체종료 없음). */
        fun startDemo(context: Context) {
            val intent = Intent(context, LiveActivityService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_DEMO, true)
            }
            context.startForegroundService(intent)
        }
    }

    private var executor: ScheduledExecutorService? = null
    private var liveJsonUrl: String? = null
    private val polling = AtomicBoolean(false)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                if (intent.getBooleanExtra(EXTRA_DEMO, false)) {
                    // 데모: 정적 알림만 띄우고 폴링/자체종료 없음('stop' 으로만 종료).
                    ensureChannel()
                    foreground(
                        buildNotification(
                            title = "벨기에 그랑프리",
                            text = "1위 NOR 랜도 노리스 · 42/66랩",
                            chip = "L42/66",
                            currentLap = 42,
                            totalLaps = 66,
                        ),
                    )
                    return START_STICKY
                }
                val url = intent.getStringExtra(EXTRA_LIVE_JSON_URL)
                if (url.isNullOrBlank()) {
                    stopCleanly()
                    return START_NOT_STICKY
                }
                liveJsonUrl = url
                startForegroundWithPlaceholder()
                startPolling()
                return START_STICKY
            }
            else -> {
                // STOP, 또는 extras 없이 시스템이 재시작한 경우 → 표시할 게 없다.
                stopCleanly()
                return START_NOT_STICKY
            }
        }
    }

    private fun startForegroundWithPlaceholder() {
        ensureChannel()
        foreground(
            buildNotification(
                title = "F1 라이브",
                text = "라이브 세션 연결 중…",
                chip = "LIVE",
                currentLap = 0,
                totalLaps = 0,
            ),
        )
    }

    private fun foreground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startPolling() {
        if (polling.getAndSet(true)) return
        val exec = Executors.newSingleThreadScheduledExecutor()
        executor = exec
        // 즉시 1회 + 이후 주기. scheduleWithFixedDelay 로 요청이 겹치지 않게 한다.
        exec.scheduleWithFixedDelay(::pollOnce, 0, POLL_SECONDS, TimeUnit.SECONDS)
    }

    private fun pollOnce() {
        val url = liveJsonUrl ?: return
        val data =
            try {
                fetchSnapshot(url)
            } catch (_: Throwable) {
                // 일시적 실패는 마지막 알림을 유지(깜빡임 방지).
                return
            } ?: return

        if (!data.isLiveRaceOrSprint) {
            // 세션이 라이브 레이스/스프린트가 아니게 됨 → 알림 내리고 종료.
            stopCleanly()
            return
        }

        try {
            NotificationManagerCompat.from(this).notify(
                NOTIFICATION_ID,
                buildNotification(
                    title = data.title,
                    text = data.text,
                    chip = data.chip,
                    currentLap = data.currentLap,
                    totalLaps = data.totalLaps,
                ),
            )
        } catch (_: Throwable) {
            // notify 실패(권한 등)로 서비스가 죽지 않게 한다.
        }
    }

    /**
     * 프로모티드 상시 알림(Now Bar/잠금화면/상태바 chip 승격). NotificationCompat
     * 이 승격 요청/스타일의 버전 호환을 처리하므로 Android 16 미만에서는 일반 상시
     * 알림으로 자동 폴백된다. 승격 규칙: setColorized/커스텀 RemoteViews/그룹 서머리
     * 금지, contentTitle 필수, 채널 importance != MIN.
     */
    private fun buildNotification(
        title: String,
        text: String,
        chip: String,
        currentLap: Int,
        totalLaps: Int,
    ): Notification =
        if (Build.VERSION.SDK_INT >= 36) {
            buildPromotedNotification(title, text, chip, currentLap, totalLaps)
        } else {
            buildCompatNotification(title, text, currentLap, totalLaps)
        }

    /**
     * Android 16(API 36)+ 프로모티드 상시 알림. 승격은 시스템이 자동 수행하며,
     * (1) EXTRA_REQUEST_PROMOTED_ONGOING extra, (2) setOngoing, (3) contentTitle,
     * (4) 허용 스타일(ProgressStyle), (5) POST_PROMOTED_NOTIFICATIONS 권한을 갖추고
     * setColorized/커스텀뷰/그룹서머리/importance=MIN 이 아니어야 승격 자격을 얻는다.
     * 진단을 위해 hasPromotableCharacteristics / canPostPromotedNotifications 를 로그.
     */
    @RequiresApi(36)
    private fun buildPromotedNotification(
        title: String,
        text: String,
        chip: String,
        currentLap: Int,
        totalLaps: Int,
    ): Notification {
        val builder =
            Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(text)
                .setColor(ACCENT)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShortCriticalText(chip) // 상태바 chip 문구(예: L42/66)

        if (totalLaps > 0) {
            builder.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(false)
                    .setProgress(currentLap.coerceIn(0, totalLaps))
                    .setProgressSegments(
                        listOf(
                            Notification.ProgressStyle.Segment(totalLaps).setColor(TRACK),
                        ),
                    ),
            )
        }

        // 승격 요청 extra. 상수 Notification.EXTRA_REQUEST_PROMOTED_ONGOING 는 @hide 라
        // 참조 불가 → 확인된 실제 키 문자열을 사용(AOSP: "android.requestPromotedOngoing").
        builder.addExtras(
            Bundle().apply { putBoolean("android.requestPromotedOngoing", true) },
        )

        val notification = builder.build()
        val manager = getSystemService(NotificationManager::class.java)
        Log.i(
            TAG,
            "promotable=${notification.hasPromotableCharacteristics()} " +
                "canPost=${manager?.canPostPromotedNotifications()}",
        )
        return notification
    }

    /** Android 16 미만 폴백 — 일반 상시 알림(+진행 바). Now Bar 승격 없음. */
    private fun buildCompatNotification(
        title: String,
        text: String,
        currentLap: Int,
        totalLaps: Int,
    ): Notification {
        val builder =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(text)
                .setColor(ACCENT)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
        if (totalLaps > 0) {
            builder.setProgress(totalLaps, currentLap.coerceIn(0, totalLaps), false)
        }
        return builder.build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "라이브 세션",
                // 승격 자격을 위해 DEFAULT 이상. 소리는 setOnlyAlertOnce 로 억제.
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "라이브 세션 중 잠금화면/Now Bar 실시간 순위"
                setShowBadge(false)
                setSound(null, null)
            }
        manager.createNotificationChannel(channel)
    }

    private fun fetchSnapshot(url: String): LiveActivityData? {
        val connection =
            (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 8000
                readTimeout = 8000
            }
        try {
            if (connection.responseCode != 200) return null
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val snapshot = JSONObject(body).optJSONObject("snapshot") ?: return null

            val status = snapshot.optString("status")
            val sessionType = snapshot.optString("sessionType")
            val sessionName = snapshot.optString("sessionName")
            val raceLike = isRaceOrSprint(sessionType, sessionName)
            val isLive = status == "live" && raceLike

            val currentLap = snapshot.optInt("currentLap", 0)
            val totalLaps = snapshot.optInt("totalLaps", 0)
            val raceName = snapshot.optString("raceName").ifBlank { "F1 라이브" }

            val topThree = snapshot.optJSONArray("topThree")
            val leader =
                if (topThree != null && topThree.length() > 0) {
                    topThree.optJSONObject(0)
                } else {
                    null
                }
            val leaderCode = leader?.optString("code").orEmpty()
            val leaderName = leader?.optString("displayName").orEmpty()

            // 사람들이 가장 궁금해하는 "현재 1위"를 앞세우고, 랩수는 뒤에 함께.
            val lapPart = if (totalLaps > 0) " · $currentLap/${totalLaps}랩" else ""
            val text =
                when {
                    leaderCode.isNotBlank() && leaderName.isNotBlank() ->
                        "1위 $leaderCode $leaderName$lapPart"
                    leaderCode.isNotBlank() -> "1위 $leaderCode$lapPart"
                    else -> if (totalLaps > 0) "$currentLap/${totalLaps}랩" else "레이스 진행 중"
                }
            val chip = if (totalLaps > 0) "L$currentLap/$totalLaps" else "LIVE"

            return LiveActivityData(
                isLiveRaceOrSprint = isLive,
                title = raceName,
                text = text,
                chip = chip,
                currentLap = currentLap,
                totalLaps = totalLaps,
            )
        } finally {
            connection.disconnect()
        }
    }

    /** 앱 [lib/models/live_session.dart] 의 liveTextIsRaceOrSprint 규칙을 복제. */
    private fun isRaceOrSprint(sessionType: String, sessionName: String): Boolean {
        val text = "$sessionType $sessionName".lowercase()
        if (text.contains("practice") ||
            text.contains("qualifying") ||
            text.contains("shootout") ||
            text.contains("프랙티스") ||
            text.contains("퀄리")
        ) {
            return false
        }
        return text.contains("race") ||
            text.contains("sprint") ||
            text.contains("레이스") ||
            text.contains("스프린트")
    }

    private fun stopCleanly() {
        polling.set(false)
        executor?.shutdownNow()
        executor = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        polling.set(false)
        executor?.shutdownNow()
        executor = null
        super.onDestroy()
    }

    private data class LiveActivityData(
        val isLiveRaceOrSprint: Boolean,
        val title: String,
        val text: String,
        val chip: String,
        val currentLap: Int,
        val totalLaps: Int,
    )
}
