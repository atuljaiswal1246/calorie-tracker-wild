package com.neharohilla.calorietracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Cal Matters home-screen widget.
 *
 * The content is a Flutter-rendered bitmap (see WidgetService.push), so the
 * widget looks exactly like the app. Tapping anywhere opens the app straight
 * into the meal log.
 */
class CalWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val views = RemoteViews(context.packageName, R.layout.cal_widget)

    val imagePath = widgetData.getString("widget_image", null)
    views.setImageViewUri(
        R.id.widget_image,
        if (imagePath != null) Uri.parse(imagePath) else null,
    )

    // One tap anywhere -> straight into logging a meal.
    val launchIntent = HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("calmatters://log"),
    )
    views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

    appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, views) }
  }
}
