package com.video.downloader.saver.manager.free.allvideodownloader

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                // 1. Import from Insta Intent
                val importIntent = android.content.Intent(context, MainActivity::class.java).apply {
                    action = "ACTION_WIDGET_OPEN_INSTA"
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val importPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    1001,
                    importIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.btn_import_insta, importPendingIntent)

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
