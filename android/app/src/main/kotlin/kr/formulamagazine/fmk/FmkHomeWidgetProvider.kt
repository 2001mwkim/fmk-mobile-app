package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
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
      val views =
          RemoteViews(context.packageName, R.layout.fmk_home_widget).apply {
            setOnClickPendingIntent(
                R.id.widget_container,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            setTextViewText(R.id.widget_badge, widgetData.getString("fmk_widget_badge", "다음 세션"))
            setTextViewText(R.id.widget_title, widgetData.getString("fmk_widget_title", "포매코"))
            setTextViewText(
                R.id.widget_primary,
                widgetData.getString("fmk_widget_primary", "앱을 열어 일정 업데이트"),
            )
            setTextViewText(R.id.widget_secondary, widgetData.getString("fmk_widget_secondary", ""))
            setTextViewText(
                R.id.widget_updated,
                widgetData.getString("fmk_widget_updated", "업데이트 --:-- KST"),
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
