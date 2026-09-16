package com.neharohilla.calorietracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Water widget: one tap logs a glass, without opening the app.
 *
 * Unlike the calorie widget this is drawn entirely natively — a number, a bar
 * and a button — so it never needs a rendered picture and is never stale.
 * Tapping "+ 1 glass" fires a background callback (see WidgetService.
 * widgetInteractivityCallback) which writes the glass through the same rules as
 * the in-app water card and then asks this provider to redraw.
 */
class CalWaterWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val goal = widgetData.getInt("water_goal", 2500).coerceAtLeast(1)

    // Zero it if the stored day is not today — this is the midnight reset.
    val storedDay = widgetData.getString("water_day", null)
    val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    val ml = if (storedDay == today) widgetData.getInt("water_ml", 0) else 0

    val pct = (ml * 100 / goal).coerceIn(0, 100)
    val reached = ml >= goal

    appWidgetIds.forEach { id ->
      val opts = appWidgetManager.getAppWidgetOptions(id)
      val wide = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 250
      val layout = if (wide) R.layout.water_widget_wide else R.layout.water_widget
      val views = RemoteViews(context.packageName, layout)

      views.setTextViewText(R.id.water_amount, litres(ml))
      views.setTextViewText(R.id.water_goal, "of ${litres(goal)}")
      views.setProgressBar(R.id.water_bar, 100, pct, false)

      // At the goal it stops asking.
      views.setViewVisibility(R.id.water_add, if (reached) View.GONE else View.VISIBLE)
      views.setViewVisibility(R.id.water_done, if (reached) View.VISIBLE else View.GONE)

      // One tap -> a glass, in the background.
      val addIntent = HomeWidgetBackgroundIntent.getBroadcast(
          context,
          Uri.parse("calmatters://water?ml=250"),
      )
      views.setOnClickPendingIntent(R.id.water_add, addIntent)

      // Deliberately NO click on the root: when the root is clickable, most
      // launchers swallow the child's click and the "+ 1 glass" button does
      // nothing (found on a real device — the root opened the app instead).
      // The button is the only target, which is also what this widget is for.

      appWidgetManager.updateAppWidget(id, views)
    }
  }

  private fun litres(ml: Int): String =
      String.format(Locale.US, "%.1f L", ml / 1000.0)
}
