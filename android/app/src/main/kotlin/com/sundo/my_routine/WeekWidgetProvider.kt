package com.sundo.my_routine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 이번 주 7일의 달성 신호등(초록, 노랑, 빨강)을 한눈에 보여 준다. */
class WeekWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        WidgetUi.handleRefreshBroadcast(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = WidgetSnapshot.parse(widgetData.getString("snapshot", null))
        WidgetUi.onWidgetUpdate(context, snapshot)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_week)
            views.setOnClickPendingIntent(R.id.widget_root, WidgetUi.openAppIntent(context))
            if (snapshot == null) {
                views.setTextViewText(R.id.week_summary, "앱을 열어 주세요")
            } else {
                views.setTextViewText(
                    R.id.week_summary,
                    if (snapshot.streak > 0) "연속 ${snapshot.streak}일" else "",
                )
                snapshot.week.take(7).forEachIndexed { i, d ->
                    views.setTextViewText(LABELS[i], d.label)
                    views.setTextColor(LABELS[i], if (d.today) Color.parseColor("#222222") else Color.parseColor("#8A8A8A"))
                    views.setTextViewText(DOTS[i], d.day.toString())
                    views.setInt(DOTS[i], "setBackgroundResource", WidgetUi.dotBackground(d.light, d.today))
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private companion object {
        val LABELS = intArrayOf(
            R.id.wd_label_0, R.id.wd_label_1, R.id.wd_label_2, R.id.wd_label_3,
            R.id.wd_label_4, R.id.wd_label_5, R.id.wd_label_6,
        )
        val DOTS = intArrayOf(
            R.id.wd_dot_0, R.id.wd_dot_1, R.id.wd_dot_2, R.id.wd_dot_3,
            R.id.wd_dot_4, R.id.wd_dot_5, R.id.wd_dot_6,
        )
    }
}
