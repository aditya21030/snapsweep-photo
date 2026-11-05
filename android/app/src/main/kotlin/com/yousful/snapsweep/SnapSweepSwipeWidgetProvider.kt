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

class SnapSweepSwipeWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "SnapSweepSwipeWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.snapsweep_widget_swipe)

                val swipeIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("snapsweep://swipe")
                    setPackage(context.packageName)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val swipePendingIntent = PendingIntent.getActivity(
                    context,
                    202,
                    swipeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_swipe_btn_swipe, swipePendingIntent)
                views.setOnClickPendingIntent(R.id.widget_swipe_container, swipePendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update swipe widget ID: $widgetId", e)
            }
        }
    }
}
