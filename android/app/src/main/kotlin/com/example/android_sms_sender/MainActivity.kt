package com.example.android_sms_sender

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "local_sms_sender/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsCapabilityInfo" -> result.success(requestSmsCapabilityInfo())
                "getSubscriptionInfo" -> getSubscriptionInfo(result)
                "sendSms" -> sendSms(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestSmsCapabilityInfo(): Map<String, Any?> {
        return try {
            val packageManager = packageManager
            val hasSmsFeature = packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING) ||
                packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
            val hasPermission = checkSelfPermissionCompat(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
            val defaultSmsAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                SmsManager.getDefault() != null
            } else {
                true
            }
            mapOf(
                "canSendSms" to (hasSmsFeature && hasPermission && defaultSmsAvailable),
                "hasSmsFeature" to hasSmsFeature,
                "defaultSmsAvailable" to defaultSmsAvailable,
            )
        } catch (error: Exception) {
            mapOf(
                "canSendSms" to false,
                "hasSmsFeature" to false,
                "defaultSmsAvailable" to false,
                "error" to (error.message ?: "unknown error"),
            )
        }
    }

    private fun getSubscriptionInfo(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }

        try {
            val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            if (checkSelfPermissionCompat(Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                result.success(emptyList<Map<String, Any?>>())
                return
            }

            val infoList = subscriptionManager.activeSubscriptionInfoList
            val resultList = infoList?.map { info ->
                mapOf(
                    "subscriptionId" to info.subscriptionId,
                    "displayName" to info.displayName.toString(),
                    "carrierName" to info.carrierName.toString(),
                    "slotIndex" to info.simSlotIndex
                )
            } ?: emptyList()
            result.success(resultList)
        } catch (error: Exception) {
            result.error("SUBSCRIPTION_INFO_ERROR", error.message ?: "Failed to get subscription info", null)
        }
    }

    private fun sendSms(call: MethodCall, result: MethodChannel.Result) {
        val phone = call.argument<String>("phone")?.trim().orEmpty()
        val message = call.argument<String>("message")?.trim().orEmpty()
        val subscriptionId = call.argument<Int>("subscriptionId")

        if (phone.isEmpty()) {
            result.error("INVALID_PHONE", "Phone number is empty.", null)
            return
        }
        if (message.isEmpty()) {
            result.error("EMPTY_MESSAGE", "Message is empty.", null)
            return
        }
        if (checkSelfPermissionCompat(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "SEND_SMS permission is not granted.", null)
            return
        }

        val capability = requestSmsCapabilityInfo()
        if (capability["hasSmsFeature"] != true) {
            result.error("NO_SMS_FEATURE", "Device does not support SMS.", capability)
            return
        }

        try {
            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val baseSmsManager = getSystemService(SmsManager::class.java)
                if (subscriptionId != null && subscriptionId != -1) {
                    baseSmsManager.createForSubscriptionId(subscriptionId)
                } else {
                    baseSmsManager
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 && subscriptionId != null && subscriptionId != -1) {
                @Suppress("DEPRECATION")
                SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            if (smsManager == null) {
                result.error("NO_DEFAULT_SMS", "No SmsManager is available.", capability)
                return
            }

            val sentIntent = PendingIntent.getBroadcast(
                this,
                System.currentTimeMillis().toInt(),
                Intent("local_sms_sender.SMS_SENT").setPackage(packageName),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val parts = smsManager.divideMessage(message)
            if (parts.size <= 1) {
                smsManager.sendTextMessage(phone, null, message, sentIntent, null)
            } else {
                val sentIntents = ArrayList<PendingIntent>(parts.size)
                repeat(parts.size) { sentIntents.add(sentIntent) }
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            }
            result.success(
                mapOf(
                    "success" to true,
                    "parts" to parts.size,
                    "bestEffort" to true,
                    "message" to "SmsManager accepted the send request.",
                ),
            )
        } catch (error: Exception) {
            result.error("NATIVE_SEND_FAILURE", error.message ?: "Native SMS send failed.", null)
        }
    }

    private fun Context.checkSelfPermissionCompat(permission: String): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(permission)
        } else {
            PackageManager.PERMISSION_GRANTED
        }
    }
}
