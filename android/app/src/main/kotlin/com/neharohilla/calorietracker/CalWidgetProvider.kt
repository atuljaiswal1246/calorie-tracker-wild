package com.neharohilla.calorietracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Renders the Cal Matters home-screen widget from data pushed by the app. */
class CalWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val views = RemoteViews(context.packageName, R.layout.cal_widget)
    val calories = widgetData.getInt("calories", 0)
    val goal = widgetData.getInt("goal", 1500)
    val streak = widgetData.getInt("streak", 0)
    views.setTextViewText(R.id.widget_cals, "$calories / $goal")
    views.setTextViewText(R.id.widget_streak, "$streak day streak")
    appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views) }
  }
}
