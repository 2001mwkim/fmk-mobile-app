package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
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
 * 챔피언십 순위 위젯(기본 = 드라이버). 예전엔 토글로 드라이버↔컨스트럭터를
 * 오갔지만, 위젯을 종류별로 분리(iOS 와 동일)하면서 토글을 제거하고 각 위젯이
 * 한 순위만 고정 표시한다. 컨스트럭터는 [FmkConstructorStandingsWidgetProvider]
 * 서브클래스가 [showTeams] 만 true 로 바꿔 재사용한다.
 *
 * 데이터 키(stDriver·stTeam 접두)는 lib/services/fmk_home_widget_bridge.dart 의
 * _saveStandingsPayload 와 수동 동기화. 색/배경/테마 헬퍼는 FmkWidgetTheme.kt.
 */
open class FmkStandingsWidgetProvider : HomeWidgetProvider() {
  /** false = 드라이버 순위(stDriver), true = 컨스트럭터 순위(stTeam). */
  protected open val showTeams: Boolean = false

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
    val prefix = if (showTeams) "stTeam" else "stDriver"

    // 앱 설정(dark/light/system) 반영 색 해석용 Context(FmkWidgetTheme.kt).
    val renderContext = context.forFmkWidgetTheme(data)

    if (compact) {
      try {
        return buildCompact(renderContext, data, prefix)
      } catch (error: Throwable) {
        Log.e(TAG, "buildCompact failed for id=$widgetId, falling back to full", error)
      }
    }

    return try {
      buildFull(renderContext, data, prefix)
    } catch (error: Throwable) {
      Log.e(TAG, "buildFull failed for id=$widgetId, using minimal fallback", error)
      RemoteViews(renderContext.packageName, R.layout.widget_fmk_standings)
    }
  }

  private fun buildFull(
      context: Context,
      data: SharedPreferences,
      prefix: String,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_standings).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_standings)
      // 토글 없는 단일 순위 위젯: 토글 그룹 숨기고 제목으로 종류를 구분한다.
      setViewVisibility(R.id.toggle_group_standings, View.GONE)
      setTextViewText(
          R.id.tv_st_title,
          if (showTeams) "컨스트럭터 챔피언십" else "드라이버 챔피언십",
      )
      setTextColor(R.id.tv_st_title, context.fmkColor(R.color.fmk_white))
      // 순위 위젯 탭 → 순위 탭(딥링크 매핑: 앱 fmk_home_widget_bridge.dart).
      setOnClickPendingIntent(
          R.id.widget_root_standings,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://standings")),
      )

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
        setTextColor(posIds[i], if (i == 0) context.fmkColor(R.color.fmk_red) else context.fmkColor(R.color.fmk_dim))
        setInt(barIds[i], "setColorFilter", rowColor(data, "${key}Color"))
        setTextViewText(nameIds[i], data.getString("${key}Name", "").orEmpty())
        setTextColor(nameIds[i], context.fmkColor(R.color.fmk_white))
        setTextViewText(changeIds[i], data.getString("${key}Change", "").orEmpty())
        setTextColor(changeIds[i], rowColor(data, "${key}ChangeColor", context.fmkColor(R.color.fmk_dim)))
        setTextViewText(ptsIds[i], data.getString("${key}Pts", "").orEmpty())
        setTextColor(ptsIds[i], context.fmkColor(R.color.fmk_white))
      }
    }
  }

  private fun buildCompact(
      context: Context,
      data: SharedPreferences,
      prefix: String,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_standings_compact).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_standings_compact)
      setOnClickPendingIntent(
          R.id.widget_root_standings_compact,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://standings")),
      )
      setTextViewText(R.id.tv_stc_title, if (showTeams) "컨스트럭터" else "드라이버")
      setTextColor(R.id.tv_stc_title, context.fmkColor(R.color.fmk_white))

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
        setTextColor(posIds[i], if (i == 0) context.fmkColor(R.color.fmk_red) else context.fmkColor(R.color.fmk_dim))
        setInt(barIds[i], "setColorFilter", rowColor(data, "${key}Color"))
        setTextViewText(nameIds[i], data.getString("${key}Name", "").orEmpty())
        setTextColor(nameIds[i], context.fmkColor(R.color.fmk_white))
        setTextViewText(ptsIds[i], data.getString("${key}Pts", "").orEmpty())
        setTextColor(ptsIds[i], context.fmkColor(R.color.fmk_text))
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

  companion object {
    private const val TAG = "FmkStandingsWidget"
    private const val FMK_RED = -1095588 // 0xFFEF4444

    /** 이 폭(dp) 미만이면 2셀로 보고 콤팩트 레이아웃을 쓴다. */
    private const val COMPACT_MAX_WIDTH_DP = 180
  }
}

/** 컨스트럭터(팀) 챔피언십 순위 위젯 — 드라이버 위젯과 렌더링을 공유한다. */
class FmkConstructorStandingsWidgetProvider : FmkStandingsWidgetProvider() {
  override val showTeams: Boolean = true
}
