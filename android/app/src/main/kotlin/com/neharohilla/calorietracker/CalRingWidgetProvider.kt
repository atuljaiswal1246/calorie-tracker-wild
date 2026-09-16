package com.neharohilla.calorietracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Ring widget: calories taken, progress in the ring, colour by state.
 *
 * Status only — it carries no meal prompt and no logging action, because that
 * is the trigger widget's job. The content is a Flutter-rendered bitmap (the
 * app's own ring), so the numbers are as of the last time the app ran.
 */
class CalRingWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { id ->
      val opts = appWidgetManager.getAppWidgetOptions(id)
      val wide = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 250
      val views = RemoteViews(context.packageName, R.layout.ring_widget)

      val key = if (wide) "ring_medium" else "ring_small"
      val path = widgetData.getString(key, null)
          ?: widgetData.getString("ring_medium", null)
      views.setImageViewUri(
          R.id.ring_image,
          if (path != null) Uri.parse(path) else null,
      )

      // Tapping opens the app on the day's breakdown. This widget never asks
      // the user to log anything.
      val openIntent = HomeWidgetLaunchIntent.getActivity(
          context,
          MainActivity::class.java,
          Uri.parse("calmatters://calories"),
      )
      views.setOnClickPendingIntent(R.id.ring_root, openIntent)

      appWidgetManager.updateAppWidget(id, views)
    }
  }
}
