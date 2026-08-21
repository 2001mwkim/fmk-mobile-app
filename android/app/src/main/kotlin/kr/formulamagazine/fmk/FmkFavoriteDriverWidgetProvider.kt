package kr.formulamagazine.fmk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 최애 드라이버 위젯(미니멀 스탯). 데이터 키(favDriver* 접두)는
 * lib/services/fmk_home_widget_bridge.dart 의 _saveFavoriteDriverPayload 와
 * 수동 동기화 — 한쪽을 바꾸면 반드시 함께 수정할 것.
 *
 * favDriverSet=0 이면 미설정 안내를, 1 이면 이름/순위/포인트/변동을 그린다.
 * favDriverFound=0(설정했지만 순위에 없음)이면 이름만, 순위/포인트는 '—'.
 */
class FmkFavoriteDriverWidgetProvider : HomeWidgetProvider() {
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
        Log.e(TAG, "updateAppWidget failed for id=$widgetId", error)
      }
    }
  }

  private fun buildViewsSafely(context: Context, data: SharedPreferences): RemoteViews {
    return try {
      build(context, data)
    } catch (error: Throwable) {
      Log.e(TAG, "build failed, using minimal fallback", error)
      RemoteViews(context.packageName, R.layout.widget_fmk_favorite)
    }
  }

  private fun build(context: Context, data: SharedPreferences): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_fmk_favorite).apply {
      // 탭 → 앱 실행(설정 진입은 앱 내에서). 미설정/설정 모두 앱을 연다.
      setOnClickPendingIntent(
          R.id.widget_root_favorite,
          HomeWidgetLaunchIntent.getActivity(
              context, MainActivity::class.java, Uri.parse("fmkwidget://favorite")),
      )

      val isSet = data.getInt("favDriverSet", 0) == 1
      if (!isSet) {
        setViewVisibility(R.id.grp_fav_content, View.GONE)
        setViewVisibility(R.id.tv_fav_empty, View.VISIBLE)
        return@apply
      }

      setViewVisibility(R.id.grp_fav_content, View.VISIBLE)
      setViewVisibility(R.id.tv_fav_empty, View.GONE)

      val found = data.getInt("favDriverFound", 0) == 1
      val name = data.getString("favDriverName", "").orEmpty()
      setTextViewText(R.id.tv_fav_name, name)
      setInt(R.id.iv_fav_bar, "setColorFilter", rowColor(data, "favDriverColor"))

      if (found) {
        val pos = data.getInt("favDriverPos", 0)
        setTextViewText(R.id.tv_fav_pos, if (pos > 0) "P$pos" else "—")
        val pts = data.getString("favDriverPts", "").orEmpty()
        setTextViewText(R.id.tv_fav_pts, if (pts.isEmpty()) "" else "$pts PTS")
        setTextViewText(R.id.tv_fav_change, data.getString("favDriverChange", "").orEmpty())
        setTextColor(R.id.tv_fav_change, rowColor(data, "favDriverChangeColor", COLOR_DIM))
      } else {
        // 설정했지만 순위 데이터에 없음(예: 미집계) — 이름만, 나머지는 '—'.
        setTextViewText(R.id.tv_fav_pos, "—")
        setTextViewText(R.id.tv_fav_pts, "")
        setTextViewText(R.id.tv_fav_change, "")
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
    private const val TAG = "FmkFavoriteWidget"
    private const val FMK_RED = -1095588 // 0xFFEF4444
    private const val COLOR_DIM = -6184534 // 0xFFA1A1AA (@color/fmk_dim)
  }
}
