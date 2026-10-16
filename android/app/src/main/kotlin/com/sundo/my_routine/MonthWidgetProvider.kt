package com.sundo.my_routine

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONException
import org.json.JSONObject

/** 이번 달 신호등을 월요일 시작 달력으로 보여 준다. */
class MonthWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED ->
                WidgetUi.backgroundIntent(context, "myroutine://refresh").send()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val raw = widgetData.getString("snapshot", null)
        val snapshot = WidgetSnapshot.parse(raw)
        val month = parseMonth(raw)
        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.widget_month)
            v.setOnClickPendingIntent(R.id.widget_root, WidgetUi.openAppIntent(context))
            if (snapshot == null || month == null || snapshot.isStale) {
                v.setTextViewText(R.id.month_summary, "앱을 열어 주세요")
                for (n in 0 until CELLS) v.setTextViewText(CELL_IDS[n], "")
            } else {
                v.setTextViewText(R.id.month_title, month.label)
                v.setTextViewText(R.id.month_summary, if (snapshot.streak > 0) "연속 ${snapshot.streak}일" else "")
                for (n in 0 until CELLS) {
                    val day = n - month.offset
                    val cell = month.days.getOrNull(day)
                    if (day < 0 || cell == null) {
                        v.setTextViewText(CELL_IDS[n], "")
                        v.setInt(CELL_IDS[n], "setBackgroundResource", 0)
                    } else {
                        v.setTextViewText(CELL_IDS[n], cell.day.toString())
                        v.setInt(CELL_IDS[n], "setBackgroundResource", cellBackground(cell.light, cell.today))
                    }
                }
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }

    private data class MonthDay(val day: Int, val light: String, val today: Boolean)
    private data class Month(val label: String, val offset: Int, val days: List<MonthDay>)

    private fun parseMonth(json: String?): Month? {
        if (json.isNullOrEmpty()) return null
        return try {
            val m = JSONObject(json).getJSONObject("month")
            val arr = m.getJSONArray("days")
            Month(
                label = m.getString("label"),
                offset = m.getInt("offset"),
                days = (0 until arr.length()).map {
                    val d = arr.getJSONObject(it)
                    MonthDay(d.getInt("day"), d.getString("light"), d.getBoolean("today"))
                },
            )
        } catch (e: JSONException) {
            Log.e("MyRoutineWidget", "월간 위젯 데이터를 읽지 못했다: ${e.message}", e)
            null
        }
    }

    private fun cellBackground(light: String, today: Boolean): Int = when (light) {
        "green" -> if (today) R.drawable.widget_cell_green_today else R.drawable.widget_cell_green
        "yellow" -> if (today) R.drawable.widget_cell_yellow_today else R.drawable.widget_cell_yellow
        "red" -> if (today) R.drawable.widget_cell_red_today else R.drawable.widget_cell_red
        "rest" -> if (today) R.drawable.widget_cell_rest_today else R.drawable.widget_cell_rest
        else -> if (today) R.drawable.widget_cell_none_today else R.drawable.widget_cell_none
    }

    private companion object {
        const val CELLS = 42
        val CELL_IDS = intArrayOf(
            R.id.mc_0, R.id.mc_1, R.id.mc_2, R.id.mc_3, R.id.mc_4, R.id.mc_5, R.id.mc_6,
            R.id.mc_7, R.id.mc_8, R.id.mc_9, R.id.mc_10, R.id.mc_11, R.id.mc_12, R.id.mc_13,
            R.id.mc_14, R.id.mc_15, R.id.mc_16, R.id.mc_17, R.id.mc_18, R.id.mc_19, R.id.mc_20,
            R.id.mc_21, R.id.mc_22, R.id.mc_23, R.id.mc_24, R.id.mc_25, R.id.mc_26, R.id.mc_27,
            R.id.mc_28, R.id.mc_29, R.id.mc_30, R.id.mc_31, R.id.mc_32, R.id.mc_33, R.id.mc_34,
            R.id.mc_35, R.id.mc_36, R.id.mc_37, R.id.mc_38, R.id.mc_39, R.id.mc_40, R.id.mc_41,
        )
    }
}
