package com.boss.tennis_app

import android.content.Context
import android.app.AlarmManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "exact_alarm_permission"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkExactAlarmPermission") {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val isExactAlarmAllowed = alarmManager.canScheduleExactAlarms()
                result.success(isExactAlarmAllowed)
            } else {
                result.notImplemented()
            }
        }
    }
}