package com.yousful.snapsweep

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
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
                val cleanIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("snapsweep://clean")
                    setPackage(context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val cleanPendingIntent = PendingIntent.getActivity(
                    context,
                    101,
                    cleanIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_clean, cleanPendingIntent)

                // Intent to open Swipe Clean
                val swipeIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("snapsweep://swipe")
                    setPackage(context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val swipePendingIntent = PendingIntent.getActivity(
                    context,
                    102,
                    swipeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_btn_swipe, swipePendingIntent)

                // Overall widget container click
                views.setOnClickPendingIntent(R.id.widget_container, cleanPendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget ID: $widgetId", e)
            }
        }
    }
}
