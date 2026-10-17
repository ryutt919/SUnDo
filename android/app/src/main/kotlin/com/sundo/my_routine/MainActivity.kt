package com.sundo.my_routine

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // 위젯 "+" 버튼이 앱이 아직 준비되기 전에 새 인텐트로 도착해도, 나중에 Dart가
    // HomeWidget.initiallyLaunchedFromHomeWidget으로 읽을 수 있게 현재 인텐트를 갱신해 둔다.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
