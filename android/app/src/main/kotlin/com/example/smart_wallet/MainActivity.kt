package com.example.smart_wallet

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private var instance: MainActivity? = null
        private var methodChannel: MethodChannel? = null

        fun notifySmsReceived(sender: String, body: String, date: Long) {
            instance?.runOnUiThread {
                methodChannel?.invokeMethod("onSmsReceived", mapOf(
                    "sender" to sender,
                    "body" to body,
                    "date" to date
                ))
            }
        }
    }

    private val CHANNEL = "com.example.smart_wallet/sms"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onDestroy() {
        if (instance == this) {
            instance = null
            methodChannel = null
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val readGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(readGranted && receiveGranted)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                        101
                    )
                    val readGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    val receiveGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(readGranted && receiveGranted)
                }
                "getSmsInbox" -> {
                    val days = call.argument<Int>("days") ?: 30
                    val smsList = getSmsInboxList(days)
                    result.success(smsList)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getSmsInboxList(days: Int): List<Map<String, Any>> {
        val smsList = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date")
        
        val selection = if (days > 0) {
            val cutoff = System.currentTimeMillis() - (days.toLong() * 24 * 60 * 60 * 1000)
            "date > $cutoff"
        } else {
            null
        }

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, null, "date DESC")
            if (cursor != null && cursor.moveToFirst()) {
                val indexAddress = cursor.getColumnIndexOrThrow("address")
                val indexBody = cursor.getColumnIndexOrThrow("body")
                val indexDate = cursor.getColumnIndexOrThrow("date")

                do {
                    val sender = cursor.getString(indexAddress) ?: ""
                    val body = cursor.getString(indexBody) ?: ""
                    val date = cursor.getLong(indexDate)
                    
                    smsList.add(mapOf(
                        "sender" to sender,
                        "body" to body,
                        "date" to date
                    ))
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        return smsList
    }
}
