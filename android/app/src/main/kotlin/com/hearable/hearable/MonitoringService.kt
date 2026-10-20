package com.hearable.hearable

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service (type: microphone). Keeps HearAble allowed to use
 * the microphone while the screen is off or another app is open, and
 * shows a permanent "HearAble is listening" notification.
 */
class MonitoringService : Service() {

    companion object {
        var isRunning = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Notifications.ensureChannels(this)
        val notification = Notifications.monitoring(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                Notifications.MONITORING_ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(Notifications.MONITORING_ID, notification)
        }
        isRunning = true
        // Not sticky: the sound engine lives in the app, so the service
        // must not pretend to be monitoring on its own after a restart.
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The user swiped HearAble away — the sound engine has stopped.
        Notifications.showStatus(
            this,
            "HearAble monitoring stopped",
            "The app was closed. Open HearAble and tap Start monitoring to listen again."
        )
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}