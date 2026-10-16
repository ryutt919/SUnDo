package com.sundo.my_routine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** 오늘 할 습관을 보여 주고, 이모지 칸을 누르면 앱을 열지 않고 체크한다. */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // 자정이 지나거나 시간대가 바뀌면 Dart에게 위젯 데이터와 알람을 새로 만들게 한다.
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
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            render(context, views, snapshot)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun render(context: Context, v: RemoteViews, s: WidgetSnapshot?) {
        v.setOnClickPendingIntent(R.id.header, WidgetUi.openAppIntent(context))
        v.setOnClickPendingIntent(R.id.empty_text, WidgetUi.openAppIntent(context))
        v.setOnClickPendingIntent(R.id.more_text, WidgetUi.openAppIntent(context))
        for (i in 0 until ROWS) v.setViewVisibility(rowId(i), View.GONE)
        v.setViewVisibility(R.id.more_text, View.GONE)
        v.setViewVisibility(R.id.empty_text, View.GONE)

        if (s == null || s.isStale) {
            v.setTextViewText(R.id.summary, "")
            v.setProgressBar(R.id.progress, 100, 0, false)
            v.setViewVisibility(R.id.empty_text, View.VISIBLE)
            v.setTextViewText(R.id.empty_text, "앱을 열면 오늘의 루틴이 나타나요")
            return
        }

        v.setTextViewText(R.id.summary, if (s.rest) "쉬는 날" else "${s.pct}%  ${s.done}/${s.due}")
        v.setProgressBar(R.id.progress, 100, if (s.rest) 0 else s.pct, false)

        if (s.rows.isEmpty()) {
            v.setViewVisibility(R.id.empty_text, View.VISIBLE)
            v.setTextViewText(R.id.empty_text, if (s.rest) "쉬는 날이에요" else "오늘 할 습관이 없어요")
            return
        }

        s.rows.take(ROWS).forEachIndexed { i, r ->
            v.setViewVisibility(rowId(i), View.VISIBLE)
            v.setInt(rowId(i), "setBackgroundResource", WidgetUi.rowBackground(r.color))
            v.setTextViewText(timeId(i), r.time.ifEmpty { "언제든" })
            v.setTextViewText(nameId(i), "${r.emoji} ${r.name}")
            v.setTextViewText(checkId(i), if (r.done) r.emoji else "")
            v.setInt(
                checkId(i), "setBackgroundResource",
                if (r.done) R.drawable.widget_check_done else R.drawable.widget_check,
            )
            v.setOnClickPendingIntent(checkId(i), WidgetUi.backgroundIntent(context, "myroutine://toggle?id=${r.id}"))
        }
        if (s.more > 0) {
            v.setViewVisibility(R.id.more_text, View.VISIBLE)
            v.setTextViewText(R.id.more_text, "외 ${s.more}개 더 보기")
        }
    }

    private companion object {
        const val ROWS = 8
        fun rowId(i: Int) = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4, R.id.row_5, R.id.row_6, R.id.row_7)[i]
        fun timeId(i: Int) = intArrayOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4, R.id.time_5, R.id.time_6, R.id.time_7)[i]
        fun nameId(i: Int) = intArrayOf(R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3, R.id.name_4, R.id.name_5, R.id.name_6, R.id.name_7)[i]
        fun checkId(i: Int) = intArrayOf(R.id.check_0, R.id.check_1, R.id.check_2, R.id.check_3, R.id.check_4, R.id.check_5, R.id.check_6, R.id.check_7)[i]
    }
}
