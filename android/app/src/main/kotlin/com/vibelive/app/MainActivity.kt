package com.vibelive.app

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.vibelive.app/live_service"
    private var isStreaming = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLiveService" -> {
                        isStreaming = true
                        startLiveStreamService()
                        result.success(true)
                    }
                    "stopLiveService" -> {
                        isStreaming = false
                        stopLiveStreamService()
                        result.success(true)
                    }
                    "enterPiP" -> {
                        val entered = enterPiPMode()
                        result.success(entered)
                    }
                    "isPiPSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startLiveStreamService() {
        val intent = Intent(this, LiveStreamForegroundService::class.java).apply {
            action = LiveStreamForegroundService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLiveStreamService() {
        val intent = Intent(this, LiveStreamForegroundService::class.java).apply {
            action = LiveStreamForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    private fun enterPiPMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
                .build()
            enterPictureInPictureMode(params)
            true
        } catch (e: Exception) {
            false
        }
    }

    // Auto-enter PiP when user presses Home during a live stream
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isStreaming && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPiPMode()
        }
    }

    override fun onPictureInPictureModeChanged(isInPiPMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPiPMode, newConfig)
        // Notify Flutter about PiP state change
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod(
                "onPiPChanged", mapOf("isInPiP" to isInPiPMode)
            )
        }
    }
}
