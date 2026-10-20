package com.hearable.hearable

import android.app.Activity
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // ================================================================
    // SMS (Step 15)
    // ================================================================
    private val sentAction = "com.hearable.hearable.SMS_SENT"
    private val deliveredAction = "com.hearable.hearable.SMS_DELIVERED"

    private var smsChannel: MethodChannel? = null
    private var receiverRegistered = false
    private var requestCode = 0

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val id = intent.getStringExtra("id") ?: return
            val ok = resultCode == Activity.RESULT_OK
            val status = when (intent.action) {
                sentAction -> if (ok) "sent" else "failed"
                deliveredAction -> if (ok) "delivered" else "not_delivered"
                else -> return
            }
            val error = if (intent.action == sentAction && !ok) describe(resultCode) else null
            runOnUiThread {
                smsChannel?.invokeMethod(
                    "onStatus",
                    mapOf("id" to id, "status" to status, "error" to error)
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // ---------- SMS channel ----------
        val sms = MethodChannel(messenger, "hearable/sms")
        sms.setMethodCallHandler { call, result ->
            when (call.method) {
                "send" -> {
                    val id = call.argument<String>("id")
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (id == null || phone == null || message == null) {
                        result.error("ARGS", "Missing id, phone or message", null)
                    } else {
                        try {
                            sendSms(id, phone, message)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", e.message ?: "Could not send SMS", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
        smsChannel = sms
        registerStatusReceiver()

        // ---------- Background monitoring channel ----------
        MethodChannel(messenger, "hearable/background").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, MonitoringService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopService" -> {
                        stopService(Intent(this, MonitoringService::class.java))
                        result.success(true)
                    }
                    "showAlert" -> {
                        Notifications.showAlert(
                            this,
                            call.argument<String>("title") ?: "HearAble alert",
                            call.argument<String>("body") ?: ""
                        )
                        result.success(true)
                    }
                    "alertFinished" -> {
                        Notifications.cancelAlert(this)
                        setLockScreenMode(false)
                        result.success(true)
                    }
                    "showStatus" -> {
                        Notifications.showStatus(
                            this,
                            call.argument<String>("title") ?: "HearAble",
                            call.argument<String>("body") ?: ""
                        )
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> {
                        val nm = getSystemService(NotificationManager::class.java)
                        result.success(
                            if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true
                        )
                    }
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                // e.g. the phone refused to start the foreground service
                result.error("BACKGROUND_ERROR", e.message, null)
            }
        }
    }

    // ================================================================
    // Show over the lock screen ONLY when opened from an alert
    // ================================================================
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAlertIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlertIntent(intent)
    }

    private fun handleAlertIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("hearable_alert", false) == true) {
            setLockScreenMode(true)
        }
    }

    private fun setLockScreenMode(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        }
    }

    // ================================================================
    // SMS helpers
    // ================================================================
    private fun registerStatusReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(sentAction)
            addAction(deliveredAction)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(statusReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun statusIntent(action: String, id: String): PendingIntent {
        val intent = Intent(action).setPackage(packageName).putExtra("id", id)
        return PendingIntent.getBroadcast(
            this, requestCode++, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun sendSms(id: String, phone: String, message: String) {
        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = smsManager.divideMessage(message)
        val sent = ArrayList<PendingIntent>()
        val delivered = ArrayList<PendingIntent>()
        for (i in parts.indices) {
            sent.add(statusIntent(sentAction, id))
            delivered.add(statusIntent(deliveredAction, id))
        }
        smsManager.sendMultipartTextMessage(phone, null, parts, sent, delivered)
    }

    private fun describe(code: Int): String = when (code) {
        SmsManager.RESULT_ERROR_NO_SERVICE -> "No mobile service"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "Mobile network is off (airplane mode?)"
        SmsManager.RESULT_ERROR_NULL_PDU -> "Message could not be created"
        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Network failure (check SIM credit and signal)"
        else -> "SMS failed (code $code)"
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            unregisterReceiver(statusReceiver)
            receiverRegistered = false
        }
        super.onDestroy()
    }
}