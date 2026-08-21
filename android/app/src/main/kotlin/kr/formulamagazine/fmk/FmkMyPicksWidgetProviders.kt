package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * MY DRIVER / MY TEAM 위젯 — 설정(MY PICKS)에서 고른 드라이버·팀의 순위·포인트를
 * 팀 컬러로 보여준다. 데이터 키(myDriver* / myTeam*)는
 * lib/services/fmk_home_widget_bridge.dart 의 _saveMyPicksPayload 와 수동 동기화 —
 * 한쪽을 바꾸면 반드시 함께 수정할 것. iOS 대응: ios/FmkWidgets/FmkMyPicksWidgets.swift.
 *
 * my*Set=0 이면 미설정 안내(탭 → 설정 화면 딥링크 fmkwidget://mypicks),
 * my*Found=0(골랐지만 순위에 없음)이면 이름만, 순위/포인트는 '—'.
 * 두 위젯은 ID 접두(Driver/Team)만 다른 같은 레이아웃이라 베이스 클래스로 묶는다.
 */
abstract class FmkMyPickWidgetProvider : HomeWidgetProvider() {
  protected abstract val tag: String
  protected abstract val layoutRes: Int
  protected abstract val keyPrefix: String
  protected abstract val ids: Ids

  class Ids(
      val root: Int,
      val glow: Int,
      val bar: Int,
      val content: Int,
      val empty: Int,
      val kicker: Int,
      val change: Int,
      val code: Int,
      val name: Int,
      val sub: Int,
      val pos: Int,
      val pts: Int,
  )

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = buildViewsSafely(context, widgetData)
      try {
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (error: Throwable) {
        Log.e(tag, "updateAppWidget failed for id=$widgetId", error)
      }
    }
  }

  private fun buildViewsSafely(context: Context, data: SharedPreferences): RemoteViews {
    return try {
      build(context, data)
    } catch (error: Throwable) {
      Log.e(tag, "build failed, using minimal fallback", error)
      RemoteViews(context.packageName, layoutRes)
    }
  }

  /** 본문 텍스트(큰 약어/이름/보조 줄) — 드라이버/팀이 다르게 채운다. */
  protected abstract fun identity(data: SharedPreferences): Triple<String, String, String>

  private fun build(context: Context, data: SharedPreferences): RemoteViews {
    return RemoteViews(context.packageName, layoutRes).apply {
      val isSet = data.getInt("${keyPrefix}Set", 0) == 1
      // 설정됨 → 순위 탭, 미설정 → 설정 화면(MY PICKS). 딥링크 매핑은 앱
      // fmk_home_widget_bridge.dart / app.dart.
      setOnClickPendingIntent(
          ids.root,
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse(if (isSet) "fmkwidget://standings" else "fmkwidget://mypicks")),
      )

      if (!isSet) {
        setViewVisibility(ids.content, View.GONE)
        setViewVisibility(ids.glow, View.GONE)
        setViewVisibility(ids.empty, View.VISIBLE)
        return@apply
      }

      setViewVisibility(ids.content, View.VISIBLE)
      setViewVisibility(ids.glow, View.VISIBLE)
      setViewVisibility(ids.empty, View.GONE)

      // 팀 컬러는 헤드라인 옆 바 + 우상단 글로우(킥커는 레이아웃의 레드 유지).
      val accent = color(data, "${keyPrefix}Color")
      setInt(ids.bar, "setColorFilter", accent)
      setInt(ids.glow, "setColorFilter", accent)

      val (code, name, sub) = identity(data)
      setTextViewText(ids.code, code)
      setTextViewText(ids.name, name)
      setTextViewText(ids.sub, sub)
      setViewVisibility(ids.sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)

      val found = data.getInt("${keyPrefix}Found", 0) == 1
      if (found) {
        val pos = data.getInt("${keyPrefix}Pos", 0)
        setTextViewText(ids.pos, if (pos > 0) "P$pos" else "—")
        val pts = data.getString("${keyPrefix}Pts", "").orEmpty()
        setTextViewText(ids.pts, if (pts.isEmpty()) "" else "$pts PTS")
        // '—'(변동 없음)는 숨긴다 — 큰 타이포 옆 대시는 오타처럼 보인다(iOS 동일).
        val change = data.getString("${keyPrefix}Change", "").orEmpty()
        setTextViewText(ids.change, if (change == "—") "" else change)
        setTextColor(ids.change, color(data, "${keyPrefix}ChangeColor", context.fmkColor(R.color.fmk_dim)))
      } else {
        // 골랐지만 순위 데이터에 없음(예: 미집계) — 이름만, 나머지는 '—'.
        setTextViewText(ids.pos, "—")
        setTextViewText(ids.pts, "")
        setTextViewText(ids.change, "")
      }
    }
  }

  private fun color(data: SharedPreferences, key: String, fallback: Int = FMK_RED): Int {
    val stored = try {
      data.getInt(key, fallback)
    } catch (error: Throwable) {
      Log.e(tag, "Failed to read color for key=$key", error)
      fallback
    }
    return if (stored == 0) fallback else stored
  }

  /** 시스템 라이트/다크(values / values-night)에 따라 해석되는 위젯 색. */
  protected fun Context.fmkColor(resId: Int): Int =
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) getColor(resId)
      else @Suppress("DEPRECATION") resources.getColor(resId)

  companion object {
    private const val FMK_RED = -1095588 // 0xFFEF4444
  }
}

class FmkMyDriverWidgetProvider : FmkMyPickWidgetProvider() {
  override val tag = "FmkMyDriverWidget"
  override val layoutRes = R.layout.widget_fmk_my_driver
  override val keyPrefix = "myDriver"
  override val ids =
      Ids(
          root = R.id.widget_root_my_driver,
          glow = R.id.iv_myDriver_glow,
          bar = R.id.iv_myDriver_bar,
          content = R.id.grp_myDriver_content,
          empty = R.id.grp_myDriver_empty,
          kicker = R.id.tv_myDriver_kicker,
          change = R.id.tv_myDriver_change,
          code = R.id.tv_myDriver_code,
          name = R.id.tv_myDriver_name,
          sub = R.id.tv_myDriver_sub,
          pos = R.id.tv_myDriver_pos,
          pts = R.id.tv_myDriver_pts,
      )

  /** 큰 TLA / 영문 이름 / 팀명. */
  override fun identity(data: SharedPreferences): Triple<String, String, String> {
    val code = data.getString("myDriverCode", "").orEmpty()
    val nameEn = data.getString("myDriverNameEn", "").orEmpty()
    val teamEn = data.getString("myDriverTeamEn", "").orEmpty()
    return Triple(code.ifEmpty { "—" }, nameEn.ifEmpty { code }, teamEn)
  }
}

class FmkMyTeamWidgetProvider : FmkMyPickWidgetProvider() {
  override val tag = "FmkMyTeamWidget"
  override val layoutRes = R.layout.widget_fmk_my_team
  override val keyPrefix = "myTeam"
  override val ids =
      Ids(
          root = R.id.widget_root_my_team,
          glow = R.id.iv_myTeam_glow,
          bar = R.id.iv_myTeam_bar,
          content = R.id.grp_myTeam_content,
          empty = R.id.grp_myTeam_empty,
          kicker = R.id.tv_myTeam_kicker,
          change = R.id.tv_myTeam_change,
          code = R.id.tv_myTeam_code,
          name = R.id.tv_myTeam_name,
          sub = R.id.tv_myTeam_sub,
          pos = R.id.tv_myTeam_pos,
          pts = R.id.tv_myTeam_pts,
      )

  /** 팀 풀네임(대문자, 레이아웃에서 최대 2줄) / 소속 드라이버("HAM · LEC") / (없음). */
  override fun identity(data: SharedPreferences): Triple<String, String, String> {
    val code = data.getString("myTeamCode", "").orEmpty()
    val teamEn = data.getString("myTeamEn", "").orEmpty()
    val drivers =
        listOf("myTeamD1Code", "myTeamD2Code")
            .map { data.getString(it, "").orEmpty() }
            .filter { it.isNotEmpty() }
            .joinToString(" · ")
    val title = teamEn.ifEmpty { data.getString("myTeamKo", "").orEmpty().ifEmpty { code } }
    return Triple(title.uppercase().ifEmpty { "—" }, drivers, "")
  }
}
