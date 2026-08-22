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
 * 일정 위젯(기본) — 다가오는/진행 중 그랑프리의 세션 일정을 보여준다. 예전엔
 * 우상단 토글로 일정↔라이브/결과를 오갔지만, 위젯을 종류별로 분리(iOS 와 동일)
 * 하면서 토글을 제거했다. 라이브·결과 화면은 [FmkLiveResultWidgetProvider]
 * 서브클래스가 [liveResult] 만 true 로 바꿔 렌더링을 재사용한다.
 */
open class FmkHomeWidgetProvider : HomeWidgetProvider() {
  /** false = 일정(buildDefault), true = 라이브·결과(buildLive). */
  protected open val liveResult: Boolean = false

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
    val mode = try {
      data.getString("mode", "default")
    } catch (error: Throwable) {
      Log.e(TAG, "Failed to read mode for id=$widgetId", error)
      "default"
    }

    // 앱 설정(dark/light/system)을 반영한 색 해석용 Context. 텍스트 색·배경을
    // 이 Context 로 통일해 런처 모드와 무관하게 일치시킨다(FmkWidgetTheme.kt).
    val renderContext = context.forFmkWidgetTheme(data)

    if (compact) {
      try {
        return buildCompact(renderContext, data, mode)
      } catch (error: Throwable) {
        Log.e(TAG, "buildCompact failed for id=$widgetId, falling back to full", error)
      }
    }

    // 위젯 종류에 따라 고정: 라이브·결과 위젯이면 라이브 레이아웃, 일정 위젯이면
    // 일정 레이아웃(토글 없음).
    if (liveResult) {
      return try {
        buildLive(renderContext, data)
      } catch (error: Throwable) {
        Log.e(TAG, "buildLive failed for id=$widgetId, using minimal fallback", error)
        buildMinimal(renderContext, data)
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
      setViewVisibility(R.id.toggle_group_default, View.GONE)
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

  private fun buildLive(context: Context, data: SharedPreferences): RemoteViews {
    val lapTotal = data.getInt("lapTotal", 0).coerceAtLeast(0)
    val lapCurrent = data.getInt("lapCurrent", 0).coerceIn(0, lapTotal.takeIf { it > 0 } ?: 0)
    val flag = data.getString("gpFlag", "").orEmpty()
    val gpName = data.getString("gpName", "비아 포뮬러").orEmpty()

    return RemoteViews(context.packageName, R.layout.widget_fmk_live).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_live)
      // 정적 @color 텍스트를 renderContext 로 강제(테마 일치). 액센트 바 색은
      // 팀 컬러라 별도(setColorFilter)로 유지된다.
      setTextColor(R.id.tv_live_badge, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_gp_name_live, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_lap_cur, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_lap_total, context.fmkColor(R.color.fmk_faint))
      setTextColor(R.id.tv_p1_pos, context.fmkColor(R.color.fmk_red))
      setTextColor(R.id.tv_p2_pos, context.fmkColor(R.color.fmk_dim))
      setTextColor(R.id.tv_p3_pos, context.fmkColor(R.color.fmk_dim))
      setTextColor(R.id.tv_p1_name, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_p2_name, context.fmkColor(R.color.fmk_text))
      setTextColor(R.id.tv_p3_name, context.fmkColor(R.color.fmk_text))
      setTextColor(R.id.tv_p1_time, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_p2_time, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_p3_time, context.fmkColor(R.color.fmk_white))
      // 라이브/결과 화면 탭 → 라이브 센터 탭.
      setOnClickPendingIntent(
          R.id.widget_root_live,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://live")),
      )

      // 토글 없는 라이브·결과 전용 위젯: 토글 그룹은 항상 숨긴다.
      setViewVisibility(R.id.toggle_group_live, View.GONE)

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
      // 배경색 대입 대신 흰색 라운드 바(src)에 컬러필터 — 라운딩 유지.
      setInt(R.id.view_p1_accent, "setColorFilter", accentColor(data, "p1Color"))
      setInt(R.id.view_p2_accent, "setColorFilter", accentColor(data, "p2Color"))
      setInt(R.id.view_p3_accent, "setColorFilter", accentColor(data, "p3Color"))
    }
  }

  /**
   * 2x2 콤팩트 화면. 토글 없이 모드별 핵심 한 가지만 크게 보여준다.
   * · live: LIVE 뱃지 + P1 드라이버 (+ 랩 or 기록)
   * · result: 결과 뱃지 + 우승 드라이버 + 기록
   * · default: 브랜드 킥커 + 다음 세션명 + 시작 시간(KST)
   */
  private fun buildCompact(
      context: Context,
      data: SharedPreferences,
      mode: String?,
  ): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_compact).apply {
      applyFmkWidgetBackground(context, data, R.id.widget_root_compact)
      setTextColor(R.id.tv_c_kicker, context.fmkColor(R.color.fmk_faint))
      setTextColor(R.id.tv_c_badge, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_gp, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_label, context.fmkColor(R.color.fmk_red))
      setTextColor(R.id.tv_c_big, context.fmkColor(R.color.fmk_white))
      setTextColor(R.id.tv_c_sub, context.fmkColor(R.color.fmk_dim))
      // 위젯 종류에 맞춰 딥링크: 라이브·결과 → 라이브 탭, 일정 → 홈 탭.
      val target = if (liveResult) "live" else "home"
      setOnClickPendingIntent(
          R.id.widget_root_compact,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://$target")),
      )

      if (liveResult) {
        val flag = data.getString("gpFlag", "").orEmpty()
        val gpName = data.getString("gpName", "비아 포뮬러").orEmpty()
        setTextViewText(
            R.id.tv_c_gp,
            listOf(flag, gpName).filter { it.isNotBlank() }.joinToString(" "),
        )
        setViewVisibility(R.id.tv_c_kicker, View.GONE)
        setViewVisibility(R.id.tv_c_badge, View.VISIBLE)

        val isResult = mode == "result" || data.getString("liveBadge", "LIVE") == "RESULT"
        setTextViewText(R.id.tv_c_badge, if (isResult) "결과" else "LIVE")
        setTextViewText(R.id.tv_c_label, if (isResult) "우승" else "P1")
        setTextViewText(R.id.tv_c_big, data.getString("p1Name", "").dashIfBlank())

        val lapTotal = data.getInt("lapTotal", 0)
        val lapCurrent = data.getInt("lapCurrent", 0)
        val sub =
            if (!isResult && lapTotal > 0) "LAP $lapCurrent / $lapTotal"
            else data.getString("p1Time", "").dashIfBlank()
        setTextViewText(R.id.tv_c_sub, sub)
      } else {
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

    /** 이 폭(dp) 미만이면 2셀로 보고 콤팩트 레이아웃을 쓴다(2셀 ≈ 110~150dp). */
    private const val COMPACT_MAX_WIDTH_DP = 180
  }
}

/**
 * 라이브·결과 위젯 — 라이브 세션이 있으면 라이브 순위, 평소엔 최근 확정 세션
 * 결과 Top3 를 보여준다. 일정 위젯([FmkHomeWidgetProvider])과 렌더링을 공유하되
 * [liveResult] 만 true 로 바꿔 라이브 레이아웃을 고정한다.
 */
class FmkLiveResultWidgetProvider : FmkHomeWidgetProvider() {
  override val liveResult: Boolean = true
}
