package com.example.mvp_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "PomodoroSupervisor"
        private const val CHANNEL = "mvp_app/supervisor_debug"
        private const val REQUEST_STAGE_3 = 93101
        private const val REQUEST_STAGE_6 = 93102
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDebugAlarms" -> {
                    val sessionId = call.argument<String>("sessionId")
                    val stage3AtMillis = call.argument<Number>("stage3AtMillis")?.toLong()
                    val stage6AtMillis = call.argument<Number>("stage6AtMillis")?.toLong()
                    if (sessionId == null || stage3AtMillis == null || stage6AtMillis == null) {
                        result.error("invalid_args", "Missing debug alarm arguments", null)
                        return@setMethodCallHandler
                    }
                    scheduleDebugAlarm(REQUEST_STAGE_3, "3m", sessionId, stage3AtMillis)
                    scheduleDebugAlarm(REQUEST_STAGE_6, "6m", sessionId, stage6AtMillis)
                    result.success(null)
                }
                "cancelDebugAlarms" -> {
                    cancelDebugAlarm(REQUEST_STAGE_3, "3m")
                    cancelDebugAlarm(REQUEST_STAGE_6, "6m")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "MainActivity.onPause")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "MainActivity.onStop")
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "MainActivity.onResume")
    }

    private fun scheduleDebugAlarm(
        requestCode: Int,
        stage: String,
        sessionId: String,
        triggerAtMillis: Long,
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildDebugPendingIntent(requestCode, stage, sessionId)
        Log.d(
            TAG,
            "Scheduling native debug alarm requestCode=$requestCode stage=$stage session=$sessionId triggerAtMillis=$triggerAtMillis now=${System.currentTimeMillis()}"
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        }
    }

    private fun cancelDebugAlarm(requestCode: Int, stage: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildDebugPendingIntent(requestCode, stage, "cancel")
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        Log.d(TAG, "Cancelled native debug alarm requestCode=$requestCode stage=$stage")
    }

    private fun buildDebugPendingIntent(
        requestCode: Int,
        stage: String,
        sessionId: String,
    ): PendingIntent {
        val intent = Intent(this, SupervisorNotificationDebugReceiver::class.java).apply {
            action = "com.example.mvp_app.DEBUG_SUPERVISOR_NOTIFICATION.$stage"
            putExtra("stage", stage)
            putExtra("sessionId", sessionId)
            putExtra("requestCode", requestCode)
        }
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
