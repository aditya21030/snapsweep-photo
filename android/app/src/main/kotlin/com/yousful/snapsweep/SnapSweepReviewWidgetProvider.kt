package com.yousful.snapsweep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SnapSweepReviewWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "SnapSweepReviewWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.snapsweep_widget_review)

                val reclaimableText = widgetData.getString("widget_reclaimable", "0 B") ?: "0 B"
                views.setTextViewText(R.id.widget_review_label, "TO REVIEW")
                views.setTextViewText(R.id.widget_review_size, reclaimableText)

                val cleanPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("snapsweep://clean")
                )
                views.setOnClickPendingIntent(R.id.widget_review_btn_clean, cleanPendingIntent)
                views.setOnClickPendingIntent(R.id.widget_review_container, cleanPendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to update review widget ID: $widgetId", e)
            }
        }
    }
}
