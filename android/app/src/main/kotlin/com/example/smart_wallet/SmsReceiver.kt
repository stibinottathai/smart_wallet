package com.example.smart_wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in messages) {
                val sender = message.originatingAddress ?: continue
                val body = message.messageBody ?: continue
                val date = message.timestampMillis

                // Save to SharedPreferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val pendingJsonStr = prefs.getString("flutter.pending_sms_imports", "[]") ?: "[]"
                try {
                    val jsonArray = JSONArray(pendingJsonStr)
                    val newSms = JSONObject()
                    newSms.put("sender", sender)
                    newSms.put("body", body)
                    newSms.put("date", date)
                    jsonArray.put(newSms)
                    prefs.edit().putString("flutter.pending_sms_imports", jsonArray.toString()).apply()
                } catch (e: Exception) {
                    e.printStackTrace()
                }

                // If MainActivity is active and has a listener, notify it
                MainActivity.notifySmsReceived(sender, body, date)
            }
        }
    }
}
