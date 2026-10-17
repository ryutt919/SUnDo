package com.sundo.my_routine

/** 남은 투두(오늘과 지난 미완료)를 보여 주고, 큰 체크 버튼으로 앱을 열지 않고 완료한다. */
class TodoWidgetProvider : RowWidgetProvider() {
    override val kind = WidgetSnapshot.KIND_TODO

    override val title = "투두"

    override fun summaryOf(s: WidgetSnapshot) = "${s.todoDone}/${s.todoTotal}"

    override fun progressOf(s: WidgetSnapshot) = if (s.todoTotal == 0) 0 else s.todoDone * 100 / s.todoTotal

    override fun emptyText(s: WidgetSnapshot) = "남은 투두가 없어요"
}
