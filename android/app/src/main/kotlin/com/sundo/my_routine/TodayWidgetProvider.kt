package com.sundo.my_routine

/** 오늘 할 습관(매일과 주간)을 보여 주고, 큰 체크 버튼을 누르면 앱을 열지 않고 체크한다. */
class TodayWidgetProvider : RowWidgetProvider() {
    override val title = "오늘의 루틴"

    override fun rowsOf(s: WidgetSnapshot) = s.rows

    override fun hiddenCountOf(s: WidgetSnapshot, shown: Int) = (s.rows.size - shown) + s.more

    override fun summaryOf(s: WidgetSnapshot) = if (s.rest) "쉬는 날" else "${s.pct}%  ${s.done}/${s.due}"

    override fun progressOf(s: WidgetSnapshot) = if (s.rest) 0 else s.pct

    override fun emptyText(s: WidgetSnapshot) = if (s.rest) "쉬는 날이에요" else "오늘 할 습관이 없어요"
}
