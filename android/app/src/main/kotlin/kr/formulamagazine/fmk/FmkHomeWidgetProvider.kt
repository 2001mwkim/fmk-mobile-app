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

// 위젯 색/배경/테마 헬퍼(Context.forFmkWidgetTheme, fmkColor,
// RemoteViews.applyFmkWidgetBackground)는 FmkWidgetTheme.kt 참조.

/**
 * 일정 위젯 — 다가오는/진행 중 그랑프리의 세션 일정을 보여준다. 예전엔 우상단
 * 토글로 일정↔라이브/결과를 오갔고 라이브 전용 서브클래스(FmkLiveResultWidget-
 * Provider)도 있었지만 2026-08 에 걷어냈다. 위젯 Provider 는 네트워크를 쓰지
 * 못해서 라이브를 유지하려면 앱이 주기 폴링을 대신 돌려야 하는데, 그 폴링이
 * Vercel 무료 한도(엣지 요청 100만)를 잡아먹었기 때문이다.
 */
class FmkHomeWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          buildViewsSafely(context, widgetData, widgetId, isCompact(appWidgetManager, widgetId))
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

  /**
   * 2셀 폭(대략 <180dp)이면 콤팩트 레이아웃을 쓴다. 옵션을 못 읽으면
   * 기본(풀) 레이아웃 — 잘못 커도 내용은 다 보이는 쪽이 안전하다.
   */
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
      compact: Boolean = false,
  ): RemoteViews {
    // 앱 설정(dark/light/system)을 반영한 색 해석용 Context. 텍스트 색·배경을
    // 이 Context 로 통일해 런처 모드와 무관하게 일치시킨다(FmkWidgetTheme.kt).
    val renderContext = context.forFmkWidgetTheme(data)

    if (compact) {
      try {
        return buildCompact(renderContext, data)
      } catch (error: Throwable) {
        Log.e(TAG, "buildCompact failed for id=$widgetId, falling back to full", error)
      }
    }

    return try {
      buildDefault(renderContext, data)
    } catch (error: Throwable) {
      Log.e(TAG, "buildDefault failed for id=$widgetId, using minimal fallback", error)
      buildMinimal(renderContext, data)
    }
  }

  /** Pure inflate of the default layout with no dynamic mutation — cannot fail on data. */
  private fun buildMinimal(context: Context, data: SharedPreferences): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_default).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_default)
      setTextColor(R.id.tv_gp_flag, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_gp_name, context.fmkColor(R.color.fmk_white))
    }
  }

  private fun buildDefault(
      context: Context,
      data: SharedPreferences,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_default).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_default)
      // 토글 없는 일정 전용 위젯: 토글 그룹은 항상 숨긴다.
      // 일정 화면 탭 → 홈 탭(딥링크 매핑: 앱 fmk_home_widget_bridge.dart).
      setOnClickPendingIntent(
          R.id.widget_root_default,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://home")),
      )

      // live 모드에서 gpFlag/gpName 은 라이브 그랑프리 정보라서, 일정 화면은
      // 전용 키(scheduleGpFlag/scheduleGpName)를 우선 사용한다(없으면 기존 키).
      val flag = data.getString("scheduleGpFlag", null) ?: data.getString("gpFlag", "")
      val name = data.getString("scheduleGpName", null) ?: data.getString("gpName", "비아 포뮬러")
      setTextViewText(R.id.tv_gp_flag, flag)
      setTextViewText(R.id.tv_gp_name, name)
      // 정적 @color 에 의존하는 GP 이름/flag 는 renderContext 로 강제(그 외 스케줄
      // 행은 아래에서 이미 context.fmkColor 로 칠한다).
      setTextColor(R.id.tv_gp_flag, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_gp_name, context.fmkColor(R.color.fmk_white))

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

      val dotIds =
          intArrayOf(
              R.id.iv_s1_dot,
              R.id.iv_s2_dot,
              R.id.iv_s3_dot,
              R.id.iv_s4_dot,
              R.id.iv_s5_dot,
          )

      // 다음 세션(1-based, 0=없음): 레드 도트 + 흰 시간. 지난 세션은 ghost 로
      // 가라앉혀 "지금 어디까지 왔는지"가 위젯만 봐도 읽히게 한다.
      val highlight = data.getInt("sessionHighlightIndex", 0)

      for (i in 0 until 5) {
        val index = i + 1
        val visible = data.getInt("session${index}Visible", 0) == 1
        setViewVisibility(rowIds[i], if (visible) View.VISIBLE else View.GONE)
        setTextViewText(nameIds[i], data.getString("session${index}Name", ""))
        setTextViewText(dateIds[i], data.getString("session${index}Date", ""))
        setTextViewText(timeIds[i], data.getString("session${index}Time", ""))

        val isNext = highlight == index
        val isPast = highlight > index
        setViewVisibility(dotIds[i], if (isNext) View.VISIBLE else View.INVISIBLE)
        setTextColor(nameIds[i], if (isNext) context.fmkColor(R.color.fmk_white) else if (isPast) context.fmkColor(R.color.fmk_ghost) else context.fmkColor(R.color.fmk_text))
        setTextColor(dateIds[i], if (isPast) context.fmkColor(R.color.fmk_ghost) else context.fmkColor(R.color.fmk_dim))
        setTextColor(timeIds[i], if (isNext) context.fmkColor(R.color.fmk_red) else if (isPast) context.fmkColor(R.color.fmk_ghost) else context.fmkColor(R.color.fmk_white))
      }
    }
  }

  /**
   * 2x2 콤팩트 화면. 브랜드 킥커 + 다음 세션명 + 시작 시간(KST)만 크게 보여준다.
   */
  private fun buildCompact(
      context: Context,
      data: SharedPreferences,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_compact).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_compact)
      setTextColor(R.id.tv_c_kicker, context.fmkColor(R.color.fmk_faint))
      setTextColor(R.id.tv_c_badge, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_gp, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_label, context.fmkColor(R.color.fmk_red))
      setTextColor(R.id.tv_c_big, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_sub, context.fmkColor(R.color.fmk_dim))
      setOnClickPendingIntent(
          R.id.widget_root_compact,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://home")),
      )

      val flag = data.getString("scheduleGpFlag", null) ?: data.getString("gpFlag", "")
      val gpName =
          data.getString("scheduleGpName", null) ?: data.getString("gpName", "비아 포뮬러")
      setTextViewText(
          R.id.tv_c_gp,
          listOf(flag.orEmpty(), gpName.orEmpty()).filter { it.isNotBlank() }.joinToString(" "),
      )
      setViewVisibility(R.id.tv_c_kicker, View.VISIBLE)
      setViewVisibility(R.id.tv_c_badge, View.GONE)

      // 다음 세션(하이라이트) 우선, 정보가 없으면 첫 행으로 폴백.
      val stored = data.getInt("sessionHighlightIndex", 0)
      val index =
          if (stored in 1..5 && data.getInt("session${stored}Visible", 0) == 1) stored else 1
      setTextViewText(R.id.tv_c_label, data.getString("session${index}Name", "").dashIfBlank())
      setTextViewText(R.id.tv_c_big, data.getString("session${index}Time", "").dashIfBlank())
      val date = data.getString("session${index}Date", "").orEmpty().trim()
      setTextViewText(R.id.tv_c_sub, if (date.isEmpty()) "KST" else "$date · KST")
    }
  }

  private fun String?.dashIfBlank(): String {
    val value = this?.trim().orEmpty()
    return if (value.isEmpty()) "---" else value
  }

  companion object {
    private const val TAG = "FmkHomeWidget"

    /** 이 폭(dp) 미만이면 2셀로 보고 콤팩트 레이아웃을 쓴다(2셀 ≈ 110~150dp). */
    private const val COMPACT_MAX_WIDTH_DP = 180
  }
}
