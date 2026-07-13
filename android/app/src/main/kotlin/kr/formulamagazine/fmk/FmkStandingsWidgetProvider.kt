package kr.formulamagazine.fmk

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 챔피언십 순위 위젯. 데이터 키(stDriver·stTeam 접두)는
 * lib/services/fmk_home_widget_bridge.dart 의 _saveStandingsPayload 와 수동
 * 동기화 — 한쪽을 바꾸면 반드시 함께 수정할 것.
 *
 * 우상단 토글로 드라이버 ↔ 팀(컨스트럭터)을 전환하고, 2셀 폭으로 줄이면
 * 콤팩트(Top 3) 레이아웃으로 자동 전환된다(FmkHomeWidgetProvider 와 동일 규칙).
 */
class FmkStandingsWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = buildViewsSafely(context, widgetData, widgetId, isCompact(appWidgetManager, widgetId))
      try {
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (error: Throwable) {
        Log.e(TAG, "updateAppWidget failed for id=$widgetId", error)
      }
    }
  }

  /** 리사이즈 시 사이즈에 맞는 레이아웃(2셀 폭 → 콤팩트)으로 다시 그린다. */
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle?,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    try {
      onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    } catch (error: Throwable) {
      Log.e(TAG, "options-changed rebuild failed for id=$appWidgetId", error)
    }
  }

  /** 드라이버/팀 토글 브로드캐스트 처리. */
  override fun onReceive(context: Context, intent: Intent) {
    val showTeams = when (intent.action) {
      ACTION_SHOW_DRIVERS -> false
      ACTION_SHOW_TEAMS -> true
      else -> {
        super.onReceive(context, intent)
        return
      }
    }

    try {
      widgetState(context).edit().putBoolean(KEY_SHOW_TEAMS, showTeams).apply()

      val manager = AppWidgetManager.getInstance(context)
      val ids =
          manager.getAppWidgetIds(
              ComponentName(context, FmkStandingsWidgetProvider::class.java)
          )
      if (ids != null && ids.isNotEmpty()) {
        onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
      }
    } catch (error: Throwable) {
      Log.e(TAG, "toggle standings view failed", error)
    }
  }

  private fun isCompact(manager: AppWidgetManager, widgetId: Int): Boolean {
    return try {
      val minWidth =
          manager.getAppWidgetOptions(widgetId)
              ?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
      minWidth in 1 until COMPACT_MAX_WIDTH_DP
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read widget options for id=$widgetId", error)
      false
    }
  }

  private fun buildViewsSafely(
      context: Context,
      data: SharedPreferences,
      widgetId: Int,
      compact: Boolean,
  ): RemoteViews {
    val showTeams = try {
      widgetState(context).getBoolean(KEY_SHOW_TEAMS, false)
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read toggle state for id=$widgetId", error)
      false
    }
    val prefix = if (showTeams) "stTeam" else "stDriver"

    if (compact) {
      try {
        return buildCompact(context, data, prefix, showTeams)
      } catch (error: Throwable) {
        Log.e(TAG, "buildCompact failed for id=$widgetId, falling back to full", error)
      }
    }

    return try {
      buildFull(context, data, prefix, showTeams)
    } catch (error: Throwable) {
      Log.e(TAG, "buildFull failed for id=$widgetId, using minimal fallback", error)
      RemoteViews(context.packageName, R.layout.widget_fmk_standings)
    }
  }

  private fun buildFull(
      context: Context,
      data: SharedPreferences,
      prefix: String,
      showTeams: Boolean,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_standings).apply {
      // 순위 위젯 탭 → 순위 탭(딥링크 매핑: 앱 fmk_home_widget_bridge.dart).
      setOnClickPendingIntent(
          R.id.widget_root_standings,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://standings")),
      )

      // 토글 활성/비활성 스타일 + 클릭 액션(FmkHomeWidgetProvider 와 동일 패턴).
      setInt(
          R.id.btn_st_drivers,
          "setBackgroundResource",
          if (showTeams) 0 else R.drawable.widget_toggle_active_bg,
      )
      setTextColor(R.id.btn_st_drivers, if (showTeams) COLOR_DIM else COLOR_WHITE)
      setInt(
          R.id.btn_st_teams,
          "setBackgroundResource",
          if (showTeams) R.drawable.widget_toggle_active_bg else 0,
      )
      setTextColor(R.id.btn_st_teams, if (showTeams) COLOR_WHITE else COLOR_DIM)
      setOnClickPendingIntent(R.id.btn_st_drivers, togglePendingIntent(context, ACTION_SHOW_DRIVERS))
      setOnClickPendingIntent(R.id.btn_st_teams, togglePendingIntent(context, ACTION_SHOW_TEAMS))

      val rowIds = intArrayOf(R.id.row_st_1, R.id.row_st_2, R.id.row_st_3, R.id.row_st_4, R.id.row_st_5)
      val posIds = intArrayOf(R.id.tv_st1_pos, R.id.tv_st2_pos, R.id.tv_st3_pos, R.id.tv_st4_pos, R.id.tv_st5_pos)
      val barIds = intArrayOf(R.id.iv_st1_bar, R.id.iv_st2_bar, R.id.iv_st3_bar, R.id.iv_st4_bar, R.id.iv_st5_bar)
      val nameIds = intArrayOf(R.id.tv_st1_name, R.id.tv_st2_name, R.id.tv_st3_name, R.id.tv_st4_name, R.id.tv_st5_name)
      val changeIds = intArrayOf(R.id.tv_st1_change, R.id.tv_st2_change, R.id.tv_st3_change, R.id.tv_st4_change, R.id.tv_st5_change)
      val ptsIds = intArrayOf(R.id.tv_st1_pts, R.id.tv_st2_pts, R.id.tv_st3_pts, R.id.tv_st4_pts, R.id.tv_st5_pts)

      for (i in 0 until 5) {
        val key = "$prefix${i + 1}"
        val visible = data.getInt("${key}Visible", 0) == 1
        setViewVisibility(rowIds[i], if (visible) View.VISIBLE else View.GONE)
        if (!visible) continue

        setTextViewText(posIds[i], data.getInt("${key}Pos", i + 1).toString())
        setTextColor(posIds[i], if (i == 0) FMK_RED else COLOR_DIM)
        setInt(barIds[i], "setColorFilter", rowColor(data, "${key}Color"))
        setTextViewText(nameIds[i], data.getString("${key}Name", "").orEmpty())
        setTextViewText(changeIds[i], data.getString("${key}Change", "").orEmpty())
        setTextColor(changeIds[i], rowColor(data, "${key}ChangeColor", COLOR_DIM))
        setTextViewText(ptsIds[i], data.getString("${key}Pts", "").orEmpty())
      }
    }
  }

  private fun buildCompact(
      context: Context,
      data: SharedPreferences,
      prefix: String,
      showTeams: Boolean,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_standings_compact).apply {
      setOnClickPendingIntent(
          R.id.widget_root_standings_compact,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://standings")),
      )
      setTextViewText(R.id.tv_stc_title, if (showTeams) "챔피언십 · 팀" else "챔피언십")

      val rowIds = intArrayOf(R.id.row_stc_1, R.id.row_stc_2, R.id.row_stc_3)
      val posIds = intArrayOf(R.id.tv_stc1_pos, R.id.tv_stc2_pos, R.id.tv_stc3_pos)
      val barIds = intArrayOf(R.id.iv_stc1_bar, R.id.iv_stc2_bar, R.id.iv_stc3_bar)
      val nameIds = intArrayOf(R.id.tv_stc1_name, R.id.tv_stc2_name, R.id.tv_stc3_name)
      val ptsIds = intArrayOf(R.id.tv_stc1_pts, R.id.tv_stc2_pts, R.id.tv_stc3_pts)

      for (i in 0 until 3) {
        val key = "$prefix${i + 1}"
        val visible = data.getInt("${key}Visible", 0) == 1
        setViewVisibility(rowIds[i], if (visible) View.VISIBLE else View.GONE)
        if (!visible) continue

        setTextViewText(posIds[i], data.getInt("${key}Pos", i + 1).toString())
        setInt(barIds[i], "setColorFilter", rowColor(data, "${key}Color"))
        setTextViewText(nameIds[i], data.getString("${key}Name", "").orEmpty())
        setTextViewText(ptsIds[i], data.getString("${key}Pts", "").orEmpty())
      }
    }
  }

  private fun rowColor(data: SharedPreferences, key: String, fallback: Int = FMK_RED): Int {
    val stored = try {
      data.getInt(key, fallback)
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read color for key=$key", error)
      fallback
    }
    return if (stored == 0) fallback else stored
  }

  private fun widgetState(context: Context): SharedPreferences =
      context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)

  private fun togglePendingIntent(context: Context, action: String): PendingIntent {
    val intent = Intent(context, FmkStandingsWidgetProvider::class.java).setAction(action)
    return PendingIntent.getBroadcast(
        context,
        if (action == ACTION_SHOW_DRIVERS) 11 else 12,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
  }

  companion object {
    private const val TAG = "FmkStandingsWidget"
    private const val FMK_RED = -1095588 // 0xFFEF4444

    private const val STATE_PREFS = "FmkStandingsWidgetState"
    private const val KEY_SHOW_TEAMS = "showTeams"
    private const val ACTION_SHOW_DRIVERS = "kr.formulamagazine.fmk.widget.standings.SHOW_DRIVERS"
    private const val ACTION_SHOW_TEAMS = "kr.formulamagazine.fmk.widget.standings.SHOW_TEAMS"

    private const val COLOR_WHITE = -328966 // 0xFFFAFAFA (@color/fmk_white)
    private const val COLOR_DIM = -6184534 // 0xFFA1A1AA (@color/fmk_dim)

    /** 이 폭(dp) 미만이면 2셀로 보고 콤팩트 레이아웃을 쓴다. */
    private const val COMPACT_MAX_WIDTH_DP = 180
  }
}
