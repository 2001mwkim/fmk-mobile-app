package kr.formulamagazine.fmk

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Build
import android.widget.RemoteViews

private const val WIDGET_THEME_KEY = "widgetThemeMode"

/**
 * 앱 설정(dark/light/system)이 확정하는 야간모드 여부. 기본은 dark.
 * system 이면 기기의 현재 라이트/다크 설정을 읽는다.
 */
internal fun Context.fmkWidgetNight(data: SharedPreferences): Boolean {
  return when (data.getString(WIDGET_THEME_KEY, "dark")) {
    "light" -> false
    "system" ->
        (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
    else -> true // dark(기본)
  }
}

/**
 * 위젯 텍스트 색(@color 리소스) 조회용 Context. 항상 [fmkWidgetNight] 로 확정한
 * 야간모드를 강제한 설정 Context 를 돌려준다. RemoteViews 의 setTextColor 는
 * 이 Context 로 색을 해석해야 배경 drawable([applyFmkWidgetBackground])과 항상
 * 일치한다 — 런처의 시스템 모드에 의존하면 다크 배경에 검은 글씨가 묻히는
 * 버그가 난다. dark/light 는 그대로, system 은 기기 설정을 읽어 강제한다.
 */
internal fun Context.forFmkWidgetTheme(data: SharedPreferences): Context {
  val night = fmkWidgetNight(data)
  val configuration = Configuration(resources.configuration)
  val nightFlag =
      if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
  configuration.uiMode =
      (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or nightFlag
  return createConfigurationContext(configuration)
}

internal fun Context.fmkColor(resId: Int): Int =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) getColor(resId)
    else @Suppress("DEPRECATION") resources.getColor(resId)

/**
 * 위젯 루트 배경을 확정 야간모드에 맞는 하드코딩 색 drawable 로 지정한다.
 * RemoteViews 배경은 런처가 inflate 하므로 @color 대신 하드코딩 drawable
 * (widget_bg_dark/light)을 써야 텍스트 색과 어긋나지 않는다.
 */
internal fun RemoteViews.applyFmkWidgetBackground(
    context: Context,
    data: SharedPreferences,
    rootId: Int,
) {
  val drawable =
      if (context.fmkWidgetNight(data)) R.drawable.widget_bg_dark
      else R.drawable.widget_bg_light
  setInt(rootId, "setBackgroundResource", drawable)
}

/** Subtle inset panel used by the wide MY PICKS layouts. */
internal fun RemoteViews.applyFmkWidgetCard(
    context: Context,
    data: SharedPreferences,
    viewId: Int,
) {
  val drawable =
      if (context.fmkWidgetNight(data)) R.drawable.widget_stat_card_dark
      else R.drawable.widget_stat_card_light
  setInt(viewId, "setBackgroundResource", drawable)
}
