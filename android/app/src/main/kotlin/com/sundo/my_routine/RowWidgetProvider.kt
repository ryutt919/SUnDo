package com.sundo.my_routine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 체크 버튼이 큰 목록형 위젯의 공통 동작. 위젯 높이에 들어가는 만큼만 행을 그리고,
 * 크기를 바꾸면 다시 그린다. 오늘의 루틴과 투두 위젯이 이 클래스를 상속한다.
 */
abstract class RowWidgetProvider : HomeWidgetProvider() {

    protected abstract val title: String
    protected abstract fun rowsOf(s: WidgetSnapshot): List<WidgetRow>
    protected abstract fun hiddenCountOf(s: WidgetSnapshot, shown: Int): Int
    protected abstract fun summaryOf(s: WidgetSnapshot): String
    protected abstract fun progressOf(s: WidgetSnapshot): Int
    protected abstract fun emptyText(s: WidgetSnapshot): String

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
        appWidgetIds.forEach { draw(context, appWidgetManager, it, snapshot) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val snapshot = WidgetSnapshot.parse(HomeWidgetPlugin.getData(context).getString("snapshot", null))
        draw(context, appWidgetManager, appWidgetId, snapshot)
    }

    private fun draw(context: Context, mgr: AppWidgetManager, id: Int, s: WidgetSnapshot?) {
        val views = RemoteViews(context.packageName, R.layout.widget_today)
        val heightDp = mgr.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 300)
        // 머리글과 진행 막대, 안쪽 여백이 약 80dp, 한 행(72dp + 간격 4dp)은 76dp
        val capacity = ((heightDp - HEADER_DP) / ROW_DP).coerceIn(1, ROWS)
        render(context, views, s, capacity)
        mgr.updateAppWidget(id, views)
    }

    private fun render(context: Context, v: RemoteViews, s: WidgetSnapshot?, capacity: Int) {
        v.setTextViewText(R.id.title, title)
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
            v.setTextViewText(R.id.empty_text, "앱을 열면 오늘 내용이 나타나요")
            return
        }

        v.setTextViewText(R.id.summary, summaryOf(s))
        v.setProgressBar(R.id.progress, 100, progressOf(s), false)

        val all = rowsOf(s)
        if (all.isEmpty()) {
            v.setViewVisibility(R.id.empty_text, View.VISIBLE)
            v.setTextViewText(R.id.empty_text, emptyText(s))
            return
        }

        // 마지막 칸은 "더 보기" 문구에 양보해야 하므로, 잘릴 때는 한 행을 덜 그린다
        val shown = if (all.size > capacity) (capacity - 1).coerceAtLeast(1) else all.size
        all.take(shown).forEachIndexed { i, r ->
            v.setViewVisibility(rowId(i), View.VISIBLE)
            v.setInt(rowId(i), "setBackgroundResource", WidgetUi.rowBackground(r.color))
            v.setTextViewText(timeId(i), r.time.ifEmpty { "언제든" })
            v.setTextViewText(nameId(i), if (r.kind == "todo") r.name else "${r.emoji} ${r.name}")
            v.setTextViewText(checkId(i), if (r.done) r.emoji else "")
            v.setInt(
                checkId(i), "setBackgroundResource",
                if (r.done) R.drawable.widget_check_done else R.drawable.widget_check,
            )
            val action = if (r.kind == "todo") "toggletodo" else "toggle"
            v.setOnClickPendingIntent(checkId(i), WidgetUi.backgroundIntent(context, "myroutine://$action?id=${r.id}"))
        }
        val hidden = hiddenCountOf(s, shown)
        if (hidden > 0) {
            v.setViewVisibility(R.id.more_text, View.VISIBLE)
            v.setTextViewText(R.id.more_text, "외 ${hidden}개 더 보기")
        }
    }

    private companion object {
        const val ROWS = 8
        const val HEADER_DP = 80
        const val ROW_DP = 76
        fun rowId(i: Int) = intArrayOf(R.id.row_0, R.id.row_1, R.id.row_2, R.id.row_3, R.id.row_4, R.id.row_5, R.id.row_6, R.id.row_7)[i]
        fun timeId(i: Int) = intArrayOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4, R.id.time_5, R.id.time_6, R.id.time_7)[i]
        fun nameId(i: Int) = intArrayOf(R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3, R.id.name_4, R.id.name_5, R.id.name_6, R.id.name_7)[i]
        fun checkId(i: Int) = intArrayOf(R.id.check_0, R.id.check_1, R.id.check_2, R.id.check_3, R.id.check_4, R.id.check_5, R.id.check_6, R.id.check_7)[i]
    }
}
