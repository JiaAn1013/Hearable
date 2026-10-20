package com.hearable.hearable

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/** Android notifications for monitoring, alerts and status messages. */
object Notifications {
    const val MONITORING_CHANNEL = "hearable_monitoring"
    const val ALERT_CHANNEL = "hearable_alerts"
    const val STATUS_CHANNEL = "hearable_status"
    const val MONITORING_ID = 1001
    const val ALERT_ID = 2001
    const val STATUS_ID = 3001

    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                MONITORING_CHANNEL, "Sound monitoring",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "Shown while HearAble is listening" }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL, "Sound alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alerts for detected sounds and emergencies"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 300, 800, 300, 800)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(
                STATUS_CHANNEL, "Monitoring status",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Tells you when monitoring stops" }
        )
    }

    private fun builder(ctx: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(ctx)
        }

    private fun openApp(ctx: Context, alert: Boolean): PendingIntent {
        val intent = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("hearable_alert", alert)
        }
        return PendingIntent.getActivity(
            ctx, if (alert) 1 else 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    fun monitoring(ctx: Context): Notification =
        builder(ctx, MONITORING_CHANNEL)
            .setContentTitle("HearAble is listening")
            .setContentText("Monitoring for alarms, glass breaking and loud bangs. Tap to open.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(openApp(ctx, false))
            .build()

    @Suppress("DEPRECATION")
    fun showAlert(ctx: Context, title: String, body: String) {
        ensureChannels(ctx)
        val open = openApp(ctx, true)
        val n = builder(ctx, ALERT_CHANNEL)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(open)
            .setFullScreenIntent(open, true) // wakes the screen
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(ALERT_ID, n)
    }

    fun cancelAlert(ctx: Context) {
        ctx.getSystemService(NotificationManager::class.java).cancel(ALERT_ID)
    }

    fun showStatus(ctx: Context, title: String, body: String) {
        ensureChannels(ctx)
        val n = builder(ctx, STATUS_CHANNEL)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx, false))
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(STATUS_ID, n)
    }
}