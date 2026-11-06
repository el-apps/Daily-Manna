package com.github.el_apps.daily_manna

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var attachedEngine: FlutterEngine? = null
    private val engineListener = RecitationEngineListener(this)
    private var resumed = false
    private var permissionResumePending = false
    private var startResult: MethodChannel.Result? = null
    private var deferredStart = false
    private val startupTimeout = Runnable {
        failStart("startup_timeout", "Recitation notification did not start in time.")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        attachedEngine = flutterEngine
        flutterEngine.addEngineLifecycleListener(engineListener)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "daily_manna/recitation_call",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startRecitation(result)
                    "update" -> {
                        val muted = call.argument<Boolean>("muted")
                        if (muted == null) {
                            result.error("invalid_arguments", "muted must be a boolean.", null)
                        } else {
                            try {
                                RecitationCallService.update(muted)
                                result.success(null)
                            } catch (error: RuntimeException) {
                                result.error("notification_update_failed", error.message, null)
                            }
                        }
                    }
                    "stop" -> {
                        cancelStart()
                        RecitationCallService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startRecitation(result: MethodChannel.Result) {
        if (startResult != null || RecitationCallService.hasSession) {
            result.error("already_started", "A recitation notification is already active.", null)
            return
        }
        if (!resumed && !permissionResumePending) {
            result.error("activity_not_visible", "Open the app before starting recitation.", null)
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED ||
            (Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED)
        ) {
            result.error("permission_denied", "Microphone and notification permissions are required.", null)
            return
        }
        startResult = result
        handler.postDelayed(startupTimeout, 5000)
        // Permission results can reach Dart before Android resumes this activity.
        deferredStart = !resumed
        if (resumed) launchService()
    }

    private fun launchService() {
        deferredStart = false
        val session = RecitationCallService.Session(
            canStart = { resumed && channel != null && !isFinishing && !isDestroyed },
            onStarted = { error ->
                if (error == null) {
                    handler.removeCallbacks(startupTimeout)
                    val result = startResult
                    startResult = null
                    result?.success(null)
                } else {
                    failStart("foreground_start_failed", error)
                }
            },
            onAction = { action -> channel?.invokeMethod(action, null) },
        )
        RecitationCallService.session = session
        try {
            val intent = Intent(this, RecitationCallService::class.java)
                .putExtra(RecitationCallService.SESSION_ID, session.id)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
        } catch (error: RuntimeException) {
            failStart("foreground_start_failed", error.message ?: "Unable to start foreground service.")
        }
    }

    private fun failStart(code: String, message: String) {
        val result = startResult
        startResult = null
        deferredStart = false
        handler.removeCallbacks(startupTimeout)
        RecitationCallService.stop(this)
        result?.error(code, message, null)
    }

    private fun cancelStart() {
        if (startResult != null) failStart("startup_cancelled", "Recitation startup was cancelled.")
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        permissionResumePending = !resumed
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onPostResume() {
        super.onPostResume()
        resumed = true
        permissionResumePending = false
        if (deferredStart) launchService()
    }

    override fun onPause() {
        resumed = false
        super.onPause()
    }

    override fun onStop() {
        permissionResumePending = false
        cancelStart()
        super.onStop()
    }

    private fun releaseRecitation() {
        cancelStart()
        RecitationCallService.stop(this)
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun disposeRecitation() {
        releaseRecitation()
        attachedEngine?.removeEngineLifecycleListener(engineListener)
        attachedEngine = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        disposeRecitation()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        disposeRecitation()
        super.onDestroy()
    }

    private class RecitationEngineListener(activity: MainActivity) : FlutterEngine.EngineLifecycleListener {
        private val activity = WeakReference(activity)

        override fun onPreEngineRestart() {
            // A hot restart discards Dart's recorder/session but keeps the engine/channel.
            activity.get()?.let {
                it.cancelStart()
                RecitationCallService.stop(it)
            }
        }

        override fun onEngineWillDestroy() {
            // Do not mutate the engine's listener set while it is being iterated.
            activity.get()?.releaseRecitation()
        }
    }
}
