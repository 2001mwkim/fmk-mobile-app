package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FmkHomeWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val mode = widgetData.getString("mode", "default")
      val views =
          if (mode == "live") {
            buildLive(context, widgetData)
          } else {
            buildDefault(context, widgetData)
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun buildDefault(context: Context, data: SharedPreferences): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_default).apply {
      setOnClickPendingIntent(
          R.id.widget_root_default,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )

      setTextViewText(R.id.tv_gp_flag, data.getString("gpFlag", ""))
      setTextViewText(R.id.tv_gp_name, data.getString("gpName", "포매코"))

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
    val progressMax = if (lapTotal > 0) lapTotal else 1
    val progressCurrent = if (lapTotal > 0) lapCurrent else 0
    val flag = data.getString("gpFlag", "").orEmpty()
    val gpName = data.getString("gpName", "포매코").orEmpty()

    return RemoteViews(context.packageName, R.layout.widget_fmk_live).apply {
      setOnClickPendingIntent(
          R.id.widget_root_live,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
      )

      setTextViewText(R.id.tv_live_badge, data.getString("liveBadge", "LIVE"))
      setTextViewText(R.id.tv_gp_name_live, listOf(flag, gpName).filter { it.isNotBlank() }.joinToString(" "))
      setTextViewText(R.id.tv_lap_cur, if (lapTotal > 0) lapCurrent.toString() else "-")
      setTextViewText(R.id.tv_lap_total, if (lapTotal > 0) "/ $lapTotal" else "/ -")
      setProgressBar(R.id.pb_lap, progressMax, progressCurrent, false)

      setTextViewText(R.id.tv_p1_code, data.getString("p1Code", "").dashIfBlank())
      setTextViewText(R.id.tv_p2_code, data.getString("p2Code", "").dashIfBlank())
      setTextViewText(R.id.tv_p3_code, data.getString("p3Code", "").dashIfBlank())
      setInt(R.id.view_p1_accent, "setBackgroundColor", data.getInt("p1Color", FMK_RED))
      setInt(R.id.view_p2_accent, "setBackgroundColor", data.getInt("p2Color", FMK_RED))
      setInt(R.id.view_p3_accent, "setBackgroundColor", data.getInt("p3Color", FMK_RED))
    }
  }

  private fun String?.dashIfBlank(): String {
    val value = this?.trim().orEmpty()
    return if (value.isEmpty()) "---" else value
  }

  companion object {
    private const val FMK_RED = -1095588 // 0xFFEF4444
  }
}
