package com.example.radio_colombia

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity: necesario para que el audio siga sonando en segundo plano.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "radio_colombia/locks")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        PlaybackLocks.acquire(applicationContext)
                        result.success(null)
                    }
                    "release" -> {
                        PlaybackLocks.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

/** Mantiene la CPU y el Wi-Fi despiertos mientras suena la radio con la pantalla apagada. */
object PlaybackLocks {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    @Suppress("DEPRECATION")
    @Synchronized
    fun acquire(context: Context) {
        val appContext = context.applicationContext
        if (wakeLock == null) {
            val power = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RadioColombia:playback")
                .apply { setReferenceCounted(false) }
        }
        if (wifiLock == null) {
            val wifi = appContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiLock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "RadioColombia:playback")
                .apply { setReferenceCounted(false) }
        }
        wakeLock?.let { if (!it.isHeld) it.acquire() }
        wifiLock?.let { if (!it.isHeld) it.acquire() }
    }

    @Synchronized
    fun release() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wifiLock?.let { if (it.isHeld) it.release() }
    }
}
