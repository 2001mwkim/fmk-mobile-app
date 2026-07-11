package kr.formulamagazine.fmk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class FmkHomeWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = buildViewsSafely(context, widgetData, widgetId)
      try {
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (error: Throwable) {
        Log.e(TAG, "updateAppWidget failed for id=$widgetId", error)
      }
    }
  }

  /** 위젯 우상단 토글: 일정/결과(라이브) 화면 전환 브로드캐스트 처리. */
  override fun onReceive(context: Context, intent: Intent) {
    val showSchedule = when (intent.action) {
      ACTION_SHOW_SCHEDULE -> true
      ACTION_SHOW_LIVE -> false
      else -> {
        super.onReceive(context, intent)
        return
      }
    }

    try {
      widgetState(context).edit().putBoolean(KEY_SHOW_SCHEDULE, showSchedule).apply()

      val manager = AppWidgetManager.getInstance(context)
      val ids =
          manager.getAppWidgetIds(
              ComponentName(context, FmkHomeWidgetProvider::class.java)
          )
      if (ids != null && ids.isNotEmpty()) {
        onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
      }
    } catch (error: Throwable) {
      Log.e(TAG, "toggle view failed", error)
    }
  }

  /**
   * Builds the RemoteViews for a widget while guaranteeing that a non-null,
   * inflatable RemoteViews is always returned. If the live/default build throws
   * for any reason we degrade gracefully so the launcher never shows
   * "위젯을 추가할 수 없습니다".
   */
  private fun buildViewsSafely(
      context: Context,
      data: SharedPreferences,
      widgetId: Int,
  ): RemoteViews {
    val mode = try {
      data.getString("mode", "default")
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read mode for id=$widgetId", error)
      "default"
    }

    // 우측 화면 데이터: live(진행 중) 또는 result(최근 확정 결과 — 상시).
    // 결과 데이터가 있는 한 토글을 항상 노출해 일정↔결과를 오갈 수 있다.
    val hasRightPane = mode == "live" || mode == "result"
    val showSchedule = try {
      resolveShowSchedule(context, mode)
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to resolve toggle state for id=$widgetId", error)
      false
    }

    if (hasRightPane && !showSchedule) {
      try {
        return buildLive(context, data)
      } catch (error: Throwable) {
        Log.e(TAG, "buildLive failed for id=$widgetId, falling back to default", error)
      }
    }

    return try {
      buildDefault(context, data, showLiveToggle = hasRightPane)
    } catch (error: Throwable) {
      Log.e(TAG, "buildDefault failed for id=$widgetId, using minimal fallback", error)
      buildMinimal(context)
    }
  }

  /**
   * 사용자가 마지막으로 고른 화면(라이브/일정)을 읽는다. default → live 로
   * 모드가 바뀌는 순간(새 세션 시작)에는 일정 화면에 두었더라도 라이브 화면으로
   * 복귀시킨다.
   */
  private fun resolveShowSchedule(context: Context, mode: String?): Boolean {
    val state = widgetState(context)
    val lastMode = state.getString(KEY_LAST_MODE, "")

    if (mode != lastMode) {
      val edit = state.edit().putString(KEY_LAST_MODE, mode)
      if (mode == "live") edit.putBoolean(KEY_SHOW_SCHEDULE, false)
      edit.apply()
    }

    return state.getBoolean(KEY_SHOW_SCHEDULE, false)
  }

  private fun widgetState(context: Context): SharedPreferences =
      context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)

  private fun togglePendingIntent(context: Context, action: String): PendingIntent {
    val intent = Intent(context, FmkHomeWidgetProvider::class.java).setAction(action)
    return PendingIntent.getBroadcast(
        context,
        if (action == ACTION_SHOW_SCHEDULE) 1 else 2,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  /** 오른쪽 칸 라벨: 라이브 진행 중이면 LIVE, 종료 후 결과 표시 중이면 결과. */
  private fun liveSideLabel(data: SharedPreferences): String =
      if (data.getString("liveBadge", "LIVE") == "RESULT") "결과" else "LIVE"

  /**
   * 세그먼트 토글(일정 | 결과)의 활성/비활성 상태와 클릭 액션을 바인딩한다.
   * 활성 칸: 빨간 배경 + 흰 글자, 비활성 칸: 배경 없음 + 회색 글자.
   */
  private fun RemoteViews.bindToggleGroup(
      context: Context,
      data: SharedPreferences,
      scheduleId: Int,
      liveId: Int,
      scheduleActive: Boolean,
  ) {
    setTextViewText(liveId, liveSideLabel(data))

    setInt(
        scheduleId,
        "setBackgroundResource",
        if (scheduleActive) R.drawable.widget_toggle_active_bg else 0,
    )
    setTextColor(scheduleId, if (scheduleActive) COLOR_WHITE else COLOR_DIM)

    setInt(
        liveId,
        "setBackgroundResource",
        if (scheduleActive) 0 else R.drawable.widget_toggle_active_bg,
    )
    setTextColor(liveId, if (scheduleActive) COLOR_DIM else COLOR_WHITE)

    setOnClickPendingIntent(scheduleId, togglePendingIntent(context, ACTION_SHOW_SCHEDULE))
    setOnClickPendingIntent(liveId, togglePendingIntent(context, ACTION_SHOW_LIVE))
  }

  /** Pure inflate of the default layout with no dynamic mutation — cannot fail on data. */
  private fun buildMinimal(context: Context): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_default)
  }

  private fun buildDefault(
      context: Context,
      data: SharedPreferences,
      showLiveToggle: Boolean = false,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_default).apply {
      setOnClickPendingIntent(
          R.id.widget_root_default,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )

      // live 모드에서 gpFlag/gpName 은 라이브 그랑프리 정보라서, 일정 화면은
      // 전용 키(scheduleGpFlag/scheduleGpName)를 우선 사용한다(없으면 기존 키).
      val flag = data.getString("scheduleGpFlag", null) ?: data.getString("gpFlag", "")
      val name = data.getString("scheduleGpName", null) ?: data.getString("gpName", "비아 포뮬러")
      setTextViewText(R.id.tv_gp_flag, flag)
      setTextViewText(R.id.tv_gp_name, name)

      if (showLiveToggle) {
        setViewVisibility(R.id.toggle_group_default, View.VISIBLE)
        bindToggleGroup(
            context,
            data,
            R.id.btn_toggle_schedule_default,
            R.id.btn_toggle_live_default,
            scheduleActive = true,
        )
      } else {
        setViewVisibility(R.id.toggle_group_default, View.GONE)
      }

      val rowIds =
          intArrayOf(R.id.row_s1, R.id.row_s2, R.id.row_s3, R.id.row_s4, R.id.row_s5)
      val nameIds =
          intArrayOf(
              R.id.tv_s1_name,
              R.id.tv_s2_name,
              R.id.tv_s3_name,
              R.id.tv_s4_name,
              R.id.tv_s5_name,
          )
      val dateIds =
          intArrayOf(
              R.id.tv_s1_date,
              R.id.tv_s2_date,
              R.id.tv_s3_date,
              R.id.tv_s4_date,
              R.id.tv_s5_date,
          )
      val timeIds =
          intArrayOf(
              R.id.tv_s1_time,
              R.id.tv_s2_time,
              R.id.tv_s3_time,
              R.id.tv_s4_time,
              R.id.tv_s5_time,
          )

      for (i in 0 until 5) {
        val index = i + 1
        val visible = data.getInt("session${index}Visible", 0) == 1
        setViewVisibility(rowIds[i], if (visible) View.VISIBLE else View.GONE)
        setTextViewText(nameIds[i], data.getString("session${index}Name", ""))
        setTextViewText(dateIds[i], data.getString("session${index}Date", ""))
        setTextViewText(timeIds[i], data.getString("session${index}Time", ""))
      }
    }
  }

  private fun buildLive(context: Context, data: SharedPreferences): RemoteViews {
    val lapTotal = data.getInt("lapTotal", 0).coerceAtLeast(0)
    val lapCurrent = data.getInt("lapCurrent", 0).coerceIn(0, lapTotal.takeIf { it > 0 } ?: 0)
    val flag = data.getString("gpFlag", "").orEmpty()
    val gpName = data.getString("gpName", "비아 포뮬러").orEmpty()

    return RemoteViews(context.packageName, R.layout.widget_fmk_live).apply {
      setOnClickPendingIntent(
          R.id.widget_root_live,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )

      bindToggleGroup(
          context,
          data,
          R.id.btn_toggle_schedule_live,
          R.id.btn_toggle_live_live,
          scheduleActive = false,
      )

      setTextViewText(R.id.tv_live_badge, data.getString("liveBadge", "LIVE"))
      setTextViewText(R.id.tv_gp_name_live, listOf(flag, gpName).filter { it.isNotBlank() }.joinToString(" "))

      // 랩 데이터가 있을 때(레이스/스프린트)만 "12 / 53 LAP" 노출.
      // 프랙티스/퀄리파잉(totalLaps 없음/0)에서는 영역 전체를 숨긴다.
      val hasLap = lapTotal > 0
      setViewVisibility(R.id.lap_group, if (hasLap) View.VISIBLE else View.GONE)
      if (hasLap) {
        setTextViewText(R.id.tv_lap_cur, lapCurrent.toString())
        setTextViewText(R.id.tv_lap_total, "/ $lapTotal")
      }

      bindDriverRow(data, 1, R.id.row_p1, R.id.tv_p1_pos, R.id.tv_p1_name, R.id.tv_p1_time)
      bindDriverRow(data, 2, R.id.row_p2, R.id.tv_p2_pos, R.id.tv_p2_name, R.id.tv_p2_time)
      bindDriverRow(data, 3, R.id.row_p3, R.id.tv_p3_pos, R.id.tv_p3_name, R.id.tv_p3_time)
      setInt(R.id.view_p1_accent, "setBackgroundColor", accentColor(data, "p1Color"))
      setInt(R.id.view_p2_accent, "setBackgroundColor", accentColor(data, "p2Color"))
      setInt(R.id.view_p3_accent, "setBackgroundColor", accentColor(data, "p3Color"))
    }
  }

  private fun RemoteViews.bindDriverRow(
      data: SharedPreferences,
      index: Int,
      rowId: Int,
      positionId: Int,
      nameId: Int,
      timeId: Int,
  ) {
    val name = data.getString("p${index}Name", "").orEmpty().trim()
    setViewVisibility(rowId, if (name.isEmpty()) View.GONE else View.VISIBLE)
    setTextViewText(positionId, data.getInt("p${index}Position", index).toString())
    setTextViewText(nameId, name.dashIfBlank())
    setTextViewText(timeId, data.getString("p${index}Time", "").dashIfBlank())
  }

  /** Reads a stored accent color, falling back to red when missing/invalid (0 == transparent). */
  private fun accentColor(data: SharedPreferences, key: String): Int {
    val stored = try {
      data.getInt(key, FMK_RED)
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read accent color for key=$key", error)
      FMK_RED
    }
    return if (stored == 0) FMK_RED else stored
  }

  private fun String?.dashIfBlank(): String {
    val value = this?.trim().orEmpty()
    return if (value.isEmpty()) "---" else value
  }

  companion object {
    private const val TAG = "FmkHomeWidget"
    private const val FMK_RED = -1095588 // 0xFFEF4444

    /** 위젯 자체 상태(토글) 저장소 — home_widget 데이터와 분리해서 보관. */
    private const val STATE_PREFS = "FmkWidgetState"
    private const val KEY_SHOW_SCHEDULE = "showSchedule"
    private const val KEY_LAST_MODE = "lastSeenMode"
    private const val ACTION_SHOW_SCHEDULE = "kr.formulamagazine.fmk.widget.SHOW_SCHEDULE"
    private const val ACTION_SHOW_LIVE = "kr.formulamagazine.fmk.widget.SHOW_LIVE"

    private const val COLOR_WHITE = -328966 // 0xFFFAFAFA (@color/fmk_white)
    private const val COLOR_DIM = -6184534 // 0xFFA1A1AA (@color/fmk_dim)
  }
}
