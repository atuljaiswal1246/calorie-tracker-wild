package com.neharohilla.calorietracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Cal Matters home-screen widget.
 *
 * The app pre-renders one bitmap per state (calm / due / last call / done /
 * over) and stores the slice of the day each belongs to. This provider runs on
 * Android's own schedule (about every 30 minutes) and picks the state whose
 * window contains the current minute — so the widget changes through the day
 * without the app ever being opened.
 */
class CalWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val views = RemoteViews(context.packageName, R.layout.cal_widget)

    val index = currentStateIndex(widgetData)
    val path = widgetData.getString("widget_image_$index", null)
    views.setImageViewUri(
        R.id.widget_image,
        if (path != null) Uri.parse(path) else null,
    )

    // One tap anywhere -> straight into logging a meal. The state and mood
    // ride along so we can measure which trigger actually caused the tap.
    val mood = widgetData.getString("state_mood_$index", "")
    val launchIntent = HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("calmatters://log?state=$index&mood=$mood"),
    )
    views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

    appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views) }
  }

  /** Which pre-rendered state covers now. Falls back to the last one. */
  private fun currentStateIndex(widgetData: SharedPreferences): Int {
    val count = widgetData.getInt("state_count", 0)
    if (count <= 0) return 0

    val raw = widgetData.getString("state_windows", null) ?: return 0
    return try {
      val windows = JSONArray(raw)
      val cal = java.util.Calendar.getInstance()
      val minute = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
          cal.get(java.util.Calendar.MINUTE)
      for (i in 0 until windows.length()) {
        val w = windows.getJSONObject(i)
        if (minute >= w.getInt("start") && minute < w.getInt("end")) return i
      }
      windows.length() - 1
    } catch (e: Exception) {
      0
    }
  }
}
