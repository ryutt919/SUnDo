package com.sundo.my_routine

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 체크 버튼이 큰 목록형 위젯의 공통 동작. 행은 RowWidgetService가 ListView로 그려
 * 위젯 안에서 위아래로 밀어 모든 항목을 본다. 오늘의 루틴과 투두 위젯이 이 클래스를 상속한다.
 */
abstract class RowWidgetProvider : HomeWidgetProvider() {

    /** WidgetSnapshot.KIND_ROUTINE 또는 WidgetSnapshot.KIND_TODO. 목록 종류와 + 버튼 딥링크를 정한다. */
    protected abstract val kind: String
    protected abstract val title: String
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
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            render(context, views, id, snapshot)
            appWidgetManager.updateAppWidget(id, views)
        }
        // 어댑터 연결은 재사용되므로, 목록이 Factory.onDataSetChanged로 새 스냅샷을 다시 읽게 알린다.
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.list)
    }

    private fun render(context: Context, v: RemoteViews, widgetId: Int, s: WidgetSnapshot?) {
        v.setTextViewText(R.id.title, title)
        v.setOnClickPendingIntent(R.id.header, WidgetUi.openAppIntent(context))
        v.setOnClickPendingIntent(R.id.empty_text, WidgetUi.openAppIntent(context))
        v.setOnClickPendingIntent(
            R.id.add_button,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("myroutine://add?kind=$kind")),
        )

        v.setRemoteAdapter(R.id.list, RowWidgetService.intent(context, widgetId, kind))
        v.setPendingIntentTemplate(R.id.list, checkTemplate(context))

        val empty = when {
            s == null || s.isStale -> "앱을 열면 오늘 내용이 나타나요"
            s.rowsFor(kind).isEmpty() -> emptyText(s)
            else -> null
        }
        v.setTextViewText(R.id.summary, if (s == null || s.isStale) "" else summaryOf(s))
        v.setProgressBar(R.id.progress, 100, if (s == null || s.isStale) 0 else progressOf(s), false)
        v.setViewVisibility(R.id.empty_text, if (empty == null) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.list, if (empty == null) View.VISIBLE else View.GONE)
        if (empty != null) v.setTextViewText(R.id.empty_text, empty)
    }

    /**
     * 행의 체크 버튼이 채워 넣는 PendingIntent 틀. 행마다 setOnClickFillInIntent로 data(myroutine://toggle...)를
     * 붙이므로 MUTABLE이어야 한다. 앱을 열지 않고 home_widget의 Dart 백그라운드 콜백으로 보낸다.
     */
    private fun checkTemplate(context: Context): PendingIntent {
        val intent = Intent(context, HomeWidgetBackgroundReceiver::class.java)
            .setAction("es.antonborri.home_widget.action.BACKGROUND")
        return PendingIntent.getBroadcast(
            context, CHECK_TEMPLATE_REQUEST, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    }

    private companion object {
        // HomeWidgetBackgroundIntent(요청 코드 0, IMMUTABLE)와 겹치지 않게 따로 둔다.
        const val CHECK_TEMPLATE_REQUEST = 1001
    }
}
