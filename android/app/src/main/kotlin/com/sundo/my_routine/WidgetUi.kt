package com.sundo.my_routine

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

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
}
