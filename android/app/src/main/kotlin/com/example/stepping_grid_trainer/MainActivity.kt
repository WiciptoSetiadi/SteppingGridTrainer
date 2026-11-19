package com.example.stepping_grid_trainer

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.steppinggrid.trainer/device"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "openWifiPanel" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val intent = Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                        } else {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        } catch (err: Exception) {
                            result.error("ERROR", err.message, null)
                        }
                    }
                }
                "enableWifi" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            @Suppress("DEPRECATION")
                            val success = wifiManager.setWifiEnabled(true)
                            result.success(success)
                        } else {
                            val intent = Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "isWifiEnabled" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        result.success(wifiManager.isWifiEnabled)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "vibrateDevice" -> {
                    val duration = call.argument<Int>("duration") ?: 120
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(duration.toLong())
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
