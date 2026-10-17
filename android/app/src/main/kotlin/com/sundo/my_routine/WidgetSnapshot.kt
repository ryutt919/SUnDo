package com.sundo.my_routine

import android.util.Log
import org.json.JSONException
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WidgetRow(
    val id: String,
    val emoji: String,
    val name: String,
    val time: String,
    val done: Boolean,
    val color: String,
    val kind: String = "habit", // "habit" 또는 "todo"
)

data class WidgetWeekDay(
    val label: String,
    val day: Int,
    val light: String,
    val today: Boolean,
)

/** Flutter가 보내는 위젯 데이터(JSON). 형식은 widget_snapshot_use_case.dart와 같다. */
data class WidgetSnapshot(
    val date: String,
    val pct: Int,
    val done: Int,
    val due: Int,
    val rest: Boolean,
    val streak: Int,
    val rows: List<WidgetRow>,
    val week: List<WidgetWeekDay>,
    val todos: List<WidgetRow> = emptyList(),
    val todoDone: Int = 0,
    val todoTotal: Int = 0,
) {
    /** 저장된 데이터가 오늘 것이 아니면 true (자정이 지났는데 아직 새로 만들지 못한 경우). */
    val isStale: Boolean get() = date != todayString()

    /** 목록형 위젯 종류(KIND_ROUTINE 또는 KIND_TODO)에 맞는 행 전체. */
    fun rowsFor(kind: String): List<WidgetRow> = if (kind == KIND_TODO) todos else rows

    companion object {
        private const val TAG = "MyRoutineWidget"
        const val KIND_ROUTINE = "routine"
        const val KIND_TODO = "todo"

        fun todayString(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        fun parse(json: String?): WidgetSnapshot? {
            if (json.isNullOrEmpty()) return null
            return try {
                val o = JSONObject(json)
                val rows = o.getJSONArray("rows")
                val week = o.getJSONArray("week")
                val todos = o.optJSONArray("todos")
                fun row(r: org.json.JSONObject) = WidgetRow(
                    id = r.getString("id"),
                    emoji = r.getString("emoji"),
                    name = r.getString("name"),
                    time = r.optString("time", ""),
                    done = r.getBoolean("done"),
                    color = r.optString("color", "#E3F7E8"),
                    kind = r.optString("kind", "habit"),
                )
                WidgetSnapshot(
                    todos = if (todos == null) emptyList() else (0 until todos.length()).map { row(todos.getJSONObject(it)) },
                    todoDone = o.optInt("todoDone", 0),
                    todoTotal = o.optInt("todoTotal", 0),
                    date = o.getString("date"),
                    pct = o.getInt("pct"),
                    done = o.getInt("done"),
                    due = o.getInt("due"),
                    rest = o.getBoolean("rest"),
                    streak = o.getInt("streak"),
                    rows = (0 until rows.length()).map { row(rows.getJSONObject(it)) },
                    week = (0 until week.length()).map {
                        val d = week.getJSONObject(it)
                        WidgetWeekDay(
                            label = d.getString("label"),
                            day = d.getInt("day"),
                            light = d.getString("light"),
                            today = d.getBoolean("today"),
                        )
                    },
                )
            } catch (e: JSONException) {
                Log.e(TAG, "위젯 데이터를 읽지 못했다: ${e.message}", e)
                null
            }
        }
    }
}
