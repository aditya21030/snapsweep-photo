package com.yousful.snapsweep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SnapSweepWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "SnapSweepWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.snapsweep_widget)

                val labelText = widgetData.getString("widget_label", "RECLAIMABLE") ?: "RECLAIMABLE"
                val reclaimableText = widgetData.getString("widget_reclaimable", "0 B") ?: "0 B"
                val countText = widgetData.getString("widget_count", "OPTIMIZED") ?: "OPTIMIZED"

                views.setTextViewText(R.id.widget_label, labelText)
                views.setTextViewText(R.id.widget_reclaimable, reclaimableText)
                views.setTextViewText(R.id.widget_count, countText)

                // Intent to open Quick Clean
                val cleanPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("snapsweep://clean")
                )
                views.setOnClickPendingIntent(R.id.widget_btn_clean, cleanPendingIntent)
                views.setOnClickPendingIntent(R.id.widget_container, cleanPendingIntent)

                // Intent to open Swipe Clean
                val swipePendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("snapsweep://swipe")
                )
                views.setOnClickPendingIntent(R.id.widget_btn_swipe, swipePendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to update widget ID: $widgetId", e)
            }
        }
    }
}
