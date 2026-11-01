package com.timetrack.enterprise

import android.Manifest
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import java.net.Inet4Address
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class PendingSms(
        val result: MethodChannel.Result,
        val phone: String,
        val message: String,
    )

    private var pendingSms: PendingSms? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "sendSms") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val phone = call.argument<String>("phone")?.trim().orEmpty()
                val message = call.argument<String>("message").orEmpty()
                if (phone.isEmpty() || message.isBlank()) {
                    result.success(mapOf("ok" to false, "detail" to "Phone number and message are required"))
                    return@setMethodCallHandler
                }
                if (!packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_MESSAGING)) {
                    result.success(mapOf("ok" to false, "detail" to "This device does not support SMS"))
                    return@setMethodCallHandler
                }

                if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                    if (pendingSms != null) {
                        result.success(mapOf("ok" to false, "detail" to "An SMS permission request is already open"))
                        return@setMethodCallHandler
                    }
                    pendingSms = PendingSms(result, phone, message)
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SMS_PERMISSION_REQUEST)
                    return@setMethodCallHandler
                }
                sendSms(result, phone, message)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "activeIpv4") {
                    result.success(activeLanIpv4())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun activeLanIpv4(): Map<String, String>? {
        val manager = getSystemService(ConnectivityManager::class.java) ?: return null
        val network = manager.activeNetwork ?: return null
        val capabilities = manager.getNetworkCapabilities(network) ?: return null
        val type = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            else -> return null
        }
        val properties = manager.getLinkProperties(network) ?: return null
        val address = properties.linkAddresses
            .asSequence()
            .map { it.address }
            .filterIsInstance<Inet4Address>()
            .firstOrNull { !it.isLoopbackAddress && !it.isLinkLocalAddress && !it.isMulticastAddress }
            ?: return null
        return mapOf(
            "ipv4" to address.hostAddress.orEmpty(),
            "interface" to properties.interfaceName.orEmpty(),
            "type" to type,
        )
    }

    @Deprecated("Deprecated by Android, retained for compatibility with the permission request flow")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_PERMISSION_REQUEST) return
        val pending = pendingSms ?: return
        pendingSms = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            sendSms(pending.result, pending.phone, pending.message)
        } else {
            pending.result.success(mapOf("ok" to false, "detail" to "SMS permission was denied"))
        }
    }

    private fun sendSms(result: MethodChannel.Result, phone: String, message: String) {
        try {
            @Suppress("DEPRECATION")
            val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            val parts = manager.divideMessage(message)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                manager.sendTextMessage(phone, null, message, null, null)
            }
            result.success(mapOf("ok" to true, "detail" to "Submitted to the device SMS service"))
        } catch (error: SecurityException) {
            result.success(mapOf("ok" to false, "detail" to "SMS permission is unavailable"))
        } catch (error: Exception) {
            result.success(mapOf("ok" to false, "detail" to (error.message ?: "SMS could not be sent")))
        }
    }

    private companion object {
        const val SMS_CHANNEL = "attendance_gateway/sms"
        const val NETWORK_CHANNEL = "timetrack/network"
        const val SMS_PERMISSION_REQUEST = 47331
    }
}