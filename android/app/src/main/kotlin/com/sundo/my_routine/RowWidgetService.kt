package com.sundo.my_routine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

/** 오늘의 루틴과 투두 위젯의 ListView 행을 만든다. 어느 위젯의 목록인지는 intent extra로 구분한다. */
class RowWidgetService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        RowFactory(applicationContext, intent.getStringExtra(EXTRA_KIND) ?: WidgetSnapshot.KIND_ROUTINE)

    companion object {
        private const val EXTRA_KIND = "kind"

        /** 위젯마다 data URI가 달라야 시스템이 Intent를 같은 것으로 보고 Factory를 섞어 쓰지 않는다. */
        fun intent(context: Context, widgetId: Int, kind: String): Intent =
            Intent(context, RowWidgetService::class.java)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                .putExtra(EXTRA_KIND, kind)
                .setData(Uri.parse("myroutine-widget://list/$kind/$widgetId"))
    }
}

private class RowFactory(
    private val context: Context,
    private val kind: String,
) : RemoteViewsService.RemoteViewsFactory {

    private var rows: List<WidgetRow> = emptyList()

    override fun onCreate() = Unit

    // 바인더 스레드에서 불리므로 동기로 읽어도 된다. 오래된(어제) 스냅샷이면 빈 목록으로 둔다.
    override fun onDataSetChanged() {
        val s = WidgetSnapshot.parse(HomeWidgetPlugin.getData(context).getString("snapshot", null))
        rows = if (s == null || s.isStale) emptyList() else s.rowsFor(kind)
    }

    override fun onDestroy() {
        rows = emptyList()
    }

    override fun getCount() = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_row_item)
        val r = rows.getOrNull(position) ?: return v
        v.setInt(R.id.row, "setBackgroundResource", WidgetUi.rowBackground(r.color))
        v.setTextViewText(R.id.time, r.time.ifEmpty { "언제든" })
        v.setTextViewText(R.id.name, if (r.kind == "todo") r.name else "${r.emoji} ${r.name}")
        v.setTextViewText(R.id.check, if (r.done) r.emoji else "")
        v.setInt(
            R.id.check, "setBackgroundResource",
            if (r.done) R.drawable.widget_check_done else R.drawable.widget_check,
        )
        // 체크 버튼만 RowWidgetProvider의 PendingIntent 틀(백그라운드 콜백)에 data를 채운다. 행 본문은 무동작.
        val action = if (r.kind == "todo") "toggletodo" else "toggle"
        v.setOnClickFillInIntent(R.id.check, Intent().setData(Uri.parse("myroutine://$action?id=${r.id}")))
        return v
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount() = 1

    override fun getItemId(position: Int) = position.toLong()

    override fun hasStableIds() = false
}
