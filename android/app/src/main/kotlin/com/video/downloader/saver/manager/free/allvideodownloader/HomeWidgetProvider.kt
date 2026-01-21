package com.video.downloader.saver.manager.free.allvideodownloader

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_widget).apply {
                
                // btn_import_insta is not in home_widget, so we omit its click handler to avoid logic errors
                // or we can map it to something else if needed.


                // 2. Repost/Gallery Intent
                val repostIntent = android.content.Intent(context, MainActivity::class.java).apply {
                    action = "ACTION_WIDGET_OPEN_GALLERY"
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val repostPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    1002,
                    repostIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_repost, repostPendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
