package com.example.mvp_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

class SupervisorNotificationDebugReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "PomodoroSupervisor"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d(
            TAG,
            "SupervisorNotificationDebugReceiver fired action=${intent?.action} extras=${intent?.extras?.toDebugString()}"
        )
    }
}

private fun Bundle.toDebugString(): String =
    keySet().joinToString(prefix = "{", postfix = "}") { key -> "$key=${get(key)}" }
