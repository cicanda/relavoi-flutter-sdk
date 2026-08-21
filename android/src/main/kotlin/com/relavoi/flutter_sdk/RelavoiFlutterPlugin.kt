package com.relavoi.flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.Manifest
import android.content.pm.PackageManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.concurrent.atomic.AtomicBoolean

class RelavoiFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private val isOnCall = AtomicBoolean(false)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.relavoi/call_state")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        startCallStateObserver()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isCallActive" -> {
                result.success(isOnCall.get())
            }
            "hasPhoneStatePermission" -> {
                val ctx = context ?: run { result.success(false); return }
                val granted = ContextCompat.checkSelfPermission(
                    ctx, Manifest.permission.READ_PHONE_STATE
                ) == PackageManager.PERMISSION_GRANTED
                result.success(granted)
            }
            "hasOverlayPermission" -> {
                val ctx = context ?: run { result.success(false); return }
                result.success(Settings.canDrawOverlays(ctx))
            }
            "requestOverlayPermission" -> {
                val act = activity ?: run { result.success(null); return }
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${act.packageName}")
                )
                act.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startCallStateObserver() {
        val ctx = context ?: return
        if (ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED
        ) return

        val tm = ctx.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            tm.registerTelephonyCallback(ctx.mainExecutor,
                object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        isOnCall.set(state != TelephonyManager.CALL_STATE_IDLE)
                    }
                })
        } else {
            @Suppress("DEPRECATION")
            tm.listen(object : PhoneStateListener() {
                @Deprecated("Deprecated in API 31")
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    isOnCall.set(state != TelephonyManager.CALL_STATE_IDLE)
                }
            }, PhoneStateListener.LISTEN_CALL_STATE)
        }
    }

    // ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
}
