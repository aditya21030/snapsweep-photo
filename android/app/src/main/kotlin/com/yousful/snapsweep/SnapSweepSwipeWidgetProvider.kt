package com.yousful.snapsweep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

                val swipePendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("snapsweep://swipe")
                )
                views.setOnClickPendingIntent(R.id.widget_swipe_btn_swipe, swipePendingIntent)
                views.setOnClickPendingIntent(R.id.widget_swipe_container, swipePendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to update swipe widget ID: $widgetId", e)
            }
        }
    }
}
