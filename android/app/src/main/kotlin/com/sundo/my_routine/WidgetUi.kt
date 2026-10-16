package com.sundo.my_routine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import java.util.Calendar

/** 두 위젯이 함께 쓰는 보조 함수. */
object WidgetUi {
    private val rowColors = listOf(
        "#FFE8E8", "#FFF1D6", "#FFFDE9", "#E3F7E8",
        "#DDF1FF", "#EBE4FF", "#FFE4F3", "#EFEFEF",
    )

    private val rowDrawables = intArrayOf(
        R.drawable.widget_row_0, R.drawable.widget_row_1, R.drawable.widget_row_2, R.drawable.widget_row_3,
        R.drawable.widget_row_4, R.drawable.widget_row_5, R.drawable.widget_row_6, R.drawable.widget_row_7,
    )

    fun rowBackground(hex: String): Int {
        val i = rowColors.indexOfFirst { it.equals(hex, ignoreCase = true) }
        return rowDrawables[if (i >= 0) i else 3]
    }

    fun dotBackground(light: String, today: Boolean): Int = when (light) {
        "green" -> if (today) R.drawable.widget_dot_green_today else R.drawable.widget_dot_green
        "yellow" -> if (today) R.drawable.widget_dot_yellow_today else R.drawable.widget_dot_yellow
        "red" -> if (today) R.drawable.widget_dot_red_today else R.drawable.widget_dot_red
        "rest" -> if (today) R.drawable.widget_dot_rest_today else R.drawable.widget_dot_rest
        else -> if (today) R.drawable.widget_dot_none_today else R.drawable.widget_dot_none
    }

    /** 위젯을 누르면 앱을 연다. */
    fun openAppIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_MAIN).setPackage(context.packageName)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        return PendingIntent.getActivity(
            context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** 앱을 열지 않고 Dart 백그라운드 콜백을 실행하는 PendingIntent. */
    fun backgroundIntent(context: Context, uri: String): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))

    const val ACTION_MIDNIGHT = "com.sundo.my_routine.ACTION_MIDNIGHT_REFRESH"

    /**
     * 다음 자정 직후에 위젯 데이터를 새로 만들게 예약한다.
     * DATE_CHANGED 같은 암시적 방송은 Android 8 이상에서 매니페스트로 못 받을 수 있어서 직접 예약한다.
     */
    fun scheduleMidnightRefresh(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val intent = Intent(context, TodayWidgetProvider::class.java).setAction(ACTION_MIDNIGHT)
        val pending = PendingIntent.getBroadcast(
            context, 77, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
    }

    /** 날짜, 시간, 시간대가 바뀌거나 자정 예약이 울리면 Dart에게 위젯 데이터를 새로 만들게 한다. */
    fun handleRefreshBroadcast(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, ACTION_MIDNIGHT -> {
                backgroundIntent(context, "myroutine://refresh").send()
                scheduleMidnightRefresh(context)
            }
        }
    }

    /** 위젯을 그릴 때마다 자정 예약을 갱신하고, 저장된 데이터가 어제 것이면 새로 만들게 한다. */
    fun onWidgetUpdate(context: Context, snapshot: WidgetSnapshot?) {
        scheduleMidnightRefresh(context)
        if (snapshot != null && snapshot.isStale) {
            backgroundIntent(context, "myroutine://refresh").send()
        }
    }
}
