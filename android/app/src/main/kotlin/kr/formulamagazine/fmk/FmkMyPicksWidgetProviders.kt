package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/** Responsive Android implementation of the iOS MY PICKS widgets. */
abstract class FmkMyPickWidgetProvider : HomeWidgetProvider() {
  protected abstract val tag: String
  protected abstract val compactLayoutRes: Int
  protected abstract val wideLayoutRes: Int
  protected abstract val keyPrefix: String
  protected abstract val ids: Ids
  protected abstract val nameColorRes: Int

  class Ids(
      val root: Int, val glow: Int, val bar: Int, val content: Int, val empty: Int,
      val kicker: Int, val change: Int, val code: Int, val name: Int, val sub: Int,
      val pos: Int, val pts: Int,
  )

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = buildViewsSafely(context, appWidgetManager, widgetId, widgetData)
      try {
        appWidgetManager.updateAppWidget(widgetId, views)
      } catch (error: Throwable) {
        Log.e(tag, "updateAppWidget failed for id=$widgetId", error)
      }
    }
  }

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
      Log.e(tag, "options-changed rebuild failed for id=$appWidgetId", error)
    }
  }

  private fun buildViewsSafely(
      context: Context,
      manager: AppWidgetManager,
      widgetId: Int,
      data: SharedPreferences,
  ): RemoteViews {
    return try {
      val compact = build(context, data, compactLayoutRes, wide = false)
      val wide = build(context, data, wideLayoutRes, wide = true)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        RemoteViews(
            mapOf(
                SizeF(COMPACT_WIDTH_DP, WIDGET_HEIGHT_DP) to compact,
                SizeF(WIDE_WIDTH_DP, WIDGET_HEIGHT_DP) to wide,
            )
        )
      } else if (widgetMinWidth(manager, widgetId) >= WIDE_BREAKPOINT_DP) wide else compact
    } catch (error: Throwable) {
      Log.e(tag, "build failed, using minimal fallback", error)
      RemoteViews(context.packageName, compactLayoutRes)
    }
  }

  private fun widgetMinWidth(manager: AppWidgetManager, widgetId: Int): Int =
      try {
        manager.getAppWidgetOptions(widgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
      } catch (error: Throwable) {
        Log.e(tag, "Failed to read widget width for id=$widgetId", error)
        0
      }

  protected abstract fun identity(data: SharedPreferences): Triple<String, String, String>

  protected open fun bindWide(
      context: Context,
      data: SharedPreferences,
      views: RemoteViews,
      theme: Context,
  ) = Unit

  private fun build(
      context: Context,
      data: SharedPreferences,
      layoutRes: Int,
      wide: Boolean,
  ): RemoteViews {
    val theme = context.forFmkWidgetTheme(data)
    return RemoteViews(context.packageName, layoutRes).apply {
      applyFmkWidgetBackground(theme, data, ids.root)
      val isSet = data.getInt("${keyPrefix}Set", 0) == 1
      setOnClickPendingIntent(
          ids.root,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java,
              Uri.parse(if (isSet) "fmkwidget://standings" else "fmkwidget://mypicks"),
          ),
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
      setTextColor(ids.kicker, theme.fmkColor(R.color.fmk_red))
      setTextColor(ids.code, theme.fmkColor(R.color.fmk_white))
      setTextColor(ids.name, theme.fmkColor(nameColorRes))
      setTextColor(ids.sub, theme.fmkColor(R.color.fmk_dim))
      setTextColor(ids.pos, theme.fmkColor(R.color.fmk_white))
      setTextColor(ids.pts, theme.fmkColor(R.color.fmk_white))

      val accent = color(data, "${keyPrefix}Color")
      setInt(ids.bar, "setColorFilter", accent)
      setInt(ids.glow, "setColorFilter", accent)
      val (code, name, sub) = identity(data)
      setTextViewText(ids.code, code)
      setTextViewText(ids.name, name)
      setTextViewText(ids.sub, sub)
      setViewVisibility(ids.sub, if (sub.isEmpty()) View.GONE else View.VISIBLE)

      if (data.getInt("${keyPrefix}Found", 0) == 1) {
        val pos = data.getInt("${keyPrefix}Pos", 0)
        setTextViewText(ids.pos, if (pos > 0) "P$pos" else "–")
        val pts = data.getString("${keyPrefix}Pts", "").orEmpty()
        setTextViewText(ids.pts, if (pts.isEmpty()) "" else if (wide) pts else "$pts PTS")
        val change = data.getString("${keyPrefix}Change", "").orEmpty()
        setTextViewText(ids.change, if (change == "–") "" else change)
        setTextColor(ids.change,
            color(data, "${keyPrefix}ChangeColor", theme.fmkColor(R.color.fmk_dim)))
      } else {
        setTextViewText(ids.pos, "–")
        setTextViewText(ids.pts, "")
        setTextViewText(ids.change, "")
      }
      if (wide) bindWide(context, data, this, theme)
    }
  }

  protected fun color(data: SharedPreferences, key: String, fallback: Int = FMK_RED): Int {
    val stored = try { data.getInt(key, fallback) } catch (error: Throwable) {
      Log.e(tag, "Failed to read color for key=$key", error)
      fallback
    }
    return if (stored == 0) fallback else stored
  }

  companion object {
    private const val COMPACT_WIDTH_DP = 110f
    private const val WIDE_WIDTH_DP = 250f
    private const val WIDGET_HEIGHT_DP = 110f
    private const val WIDE_BREAKPOINT_DP = 220
    private const val FMK_RED = -1095588
  }
}

class FmkMyDriverWidgetProvider : FmkMyPickWidgetProvider() {
  override val tag = "FmkMyDriverWidget"
  override val compactLayoutRes = R.layout.widget_fmk_my_driver
  override val wideLayoutRes = R.layout.widget_fmk_my_driver_wide
  override val keyPrefix = "myDriver"
  override val nameColorRes = R.color.fmk_text
  override val ids = Ids(
      R.id.widget_root_my_driver, R.id.iv_myDriver_glow, R.id.iv_myDriver_bar,
      R.id.grp_myDriver_content, R.id.grp_myDriver_empty, R.id.tv_myDriver_kicker,
      R.id.tv_myDriver_change, R.id.tv_myDriver_code, R.id.tv_myDriver_name,
      R.id.tv_myDriver_sub, R.id.tv_myDriver_pos, R.id.tv_myDriver_pts)

  override fun identity(data: SharedPreferences): Triple<String, String, String> {
    val code = data.getString("myDriverCode", "").orEmpty()
    return Triple(code.ifEmpty { "–" },
        data.getString("myDriverNameEn", "").orEmpty().ifEmpty { code },
        data.getString("myDriverTeamEn", "").orEmpty())
  }

  override fun bindWide(context: Context, data: SharedPreferences, views: RemoteViews, theme: Context) {
    views.applyFmkWidgetCard(context, data, R.id.card_myDriver_pos)
    views.applyFmkWidgetCard(context, data, R.id.card_myDriver_pts)
    views.setTextColor(R.id.tv_myDriver_pos_label, theme.fmkColor(R.color.fmk_dim))
    views.setTextColor(R.id.tv_myDriver_pts_label, theme.fmkColor(R.color.fmk_dim))
  }
}

class FmkMyTeamWidgetProvider : FmkMyPickWidgetProvider() {
  override val tag = "FmkMyTeamWidget"
  override val compactLayoutRes = R.layout.widget_fmk_my_team
  override val wideLayoutRes = R.layout.widget_fmk_my_team_wide
  override val keyPrefix = "myTeam"
  override val nameColorRes = R.color.fmk_dim
  override val ids = Ids(
      R.id.widget_root_my_team, R.id.iv_myTeam_glow, R.id.iv_myTeam_bar,
      R.id.grp_myTeam_content, R.id.grp_myTeam_empty, R.id.tv_myTeam_kicker,
      R.id.tv_myTeam_change, R.id.tv_myTeam_code, R.id.tv_myTeam_name,
      R.id.tv_myTeam_sub, R.id.tv_myTeam_pos, R.id.tv_myTeam_pts)

  override fun identity(data: SharedPreferences): Triple<String, String, String> {
    val code = data.getString("myTeamCode", "").orEmpty()
    val team = data.getString("myTeamEn", "").orEmpty()
        .ifEmpty { data.getString("myTeamKo", "").orEmpty().ifEmpty { code } }
    val drivers = listOf("myTeamD1Code", "myTeamD2Code")
        .map { data.getString(it, "").orEmpty() }.filter { it.isNotEmpty() }.joinToString(" · ")
    return Triple(team.uppercase().ifEmpty { "–" }, drivers, "")
  }

  override fun bindWide(context: Context, data: SharedPreferences, views: RemoteViews, theme: Context) {
    bindDriverCard(context, data, views, theme, 1, R.id.card_myTeam_driver1,
        R.id.tv_myTeam_d1_pos, R.id.tv_myTeam_d1_code, R.id.tv_myTeam_d1_pts)
    bindDriverCard(context, data, views, theme, 2, R.id.card_myTeam_driver2,
        R.id.tv_myTeam_d2_pos, R.id.tv_myTeam_d2_code, R.id.tv_myTeam_d2_pts)
  }

  private fun bindDriverCard(
      context: Context, data: SharedPreferences, views: RemoteViews, theme: Context,
      index: Int, cardId: Int, posId: Int, codeId: Int, ptsId: Int,
  ) {
    val code = data.getString("myTeamD${index}Code", "").orEmpty()
    views.setViewVisibility(cardId, if (code.isEmpty()) View.INVISIBLE else View.VISIBLE)
    if (code.isEmpty()) return
    views.applyFmkWidgetCard(context, data, cardId)
    val position = data.getInt("myTeamD${index}Pos", 0)
    views.setTextViewText(posId, if (position > 0) "P$position" else "–")
    views.setTextViewText(codeId, code)
    views.setTextViewText(ptsId, data.getString("myTeamD${index}Pts", "").orEmpty())
    views.setTextColor(posId, theme.fmkColor(R.color.fmk_dim))
    views.setTextColor(codeId, theme.fmkColor(R.color.fmk_white))
    views.setTextColor(ptsId, theme.fmkColor(R.color.fmk_white))
  }
}
