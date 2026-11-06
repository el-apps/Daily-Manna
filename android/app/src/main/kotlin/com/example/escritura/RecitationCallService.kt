package com.github.el_apps.daily_manna

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import java.util.UUID

// This service deliberately does not own audio capture, audio focus, or routing.
class RecitationCallService : Service() {
    internal class Session(
        val canStart: () -> Boolean,
        var onStarted: ((String?) -> Unit)?,
        val onAction: (String) -> Unit,
    ) {
        val id: String = UUID.randomUUID().toString()
        var muted = false
        var ready = false
        var hangingUp = false
    }

    private var sessionId: String? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val pendingIntents = mutableListOf<PendingIntent>()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val current = session
        if (current == null || intent?.getStringExtra(SESSION_ID) != current.id) {
            if (sessionId == null) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (current.ready) return START_NOT_STICKY
        sessionId = current.id
        instance = this
        try {
            check(current.canStart()) { "The activity must be visible to start microphone service." }
            createChannel()
            val notification = buildNotification(current)
            if (Build.VERSION.SDK_INT >= 30) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:recitation")
                .also { it.acquire() }
            current.ready = true
        } catch (error: RuntimeException) {
            val callback = current.onStarted
            current.onStarted = null
            stop(this)
            callback?.invoke(error.message ?: "Unable to start recitation notification.")
            return START_NOT_STICKY
        }
        val callback = current.onStarted
        current.onStarted = null
        callback?.invoke(null)
        return START_NOT_STICKY
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        check(manager.areNotificationsEnabled()) {
            "Enable notifications in Android Settings to use recitation controls."
        }
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Recitation",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Ongoing recitation recording controls"
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
            check(manager.getNotificationChannel(CHANNEL_ID).importance != NotificationManager.IMPORTANCE_NONE) {
                "Enable the Recitation notification channel in Android Settings."
            }
        }
    }

    private fun actionIntent(current: Session, action: String): PendingIntent {
        val intent = Intent(this, RecitationCallActionReceiver::class.java)
            .setAction(action)
            .setData(Uri.parse("daily-manna://recitation/${current.id}/$action"))
            .putExtra(SESSION_ID, current.id)
        return PendingIntent.getBroadcast(
            this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ).also { if (!pendingIntents.contains(it)) pendingIntents.add(it) }
    }

    private fun buildNotification(current: Session): Notification {
        // No deep link or initial route: bring the existing Flutter activity/route forward.
        val contentIntent = PendingIntent.getActivity(
            this,
            NOTIFICATION_ID,
            Intent(this, MainActivity::class.java)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ).also { if (!pendingIntents.contains(it)) pendingIntents.add(it) }
        val hangUp = actionIntent(current, HANG_UP)
        val toggleMute = actionIntent(current, TOGGLE_MUTE)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        builder.setSmallIcon(R.drawable.ic_recitation_microphone)
            .setContentTitle("Recitation")
            .setContentText(if (current.muted) "Microphone muted" else "Recording recitation")
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            // Show controls when locked, but never include recorded speech or a passage.
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(
                Notification.Action.Builder(
                    if (current.muted) android.R.drawable.ic_lock_silent_mode_off else android.R.drawable.ic_lock_silent_mode,
                    if (current.muted) "Unmute microphone" else "Mute microphone",
                    toggleMute,
                ).build(),
            )
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setStyle(
                Notification.CallStyle.forOngoingCall(
                    Person.Builder().setName("Recitation").setImportant(true).build(), hangUp,
                ),
            )
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        } else {
            builder.addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel, "Finish recitation", hangUp,
                ).build(),
            )
        }
        return builder.build()
    }

    private fun removeNotification() {
        pendingIntents.forEach { it.cancel() }
        pendingIntents.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    override fun onDestroy() {
        val current = session?.takeIf { it.id == sessionId }
        if (current != null) session = null
        if (instance === this) instance = null
        removeNotification()
        // If Android destroys just the service, let Dart finish/preserve its recorder too.
        current?.onStarted?.invoke("Recitation service was destroyed during startup.")
        if (current?.ready == true && !current.hangingUp) current.onAction(HANG_UP)
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "daily_manna/recitation_call"
        private const val NOTIFICATION_ID = 7319
        internal const val SESSION_ID = "recitationSessionId"
        internal const val TOGGLE_MUTE = "toggleMute"
        internal const val HANG_UP = "hangUp"
        internal var session: Session? = null
        private var instance: RecitationCallService? = null
        internal val hasSession: Boolean get() = session != null

        internal fun update(muted: Boolean) {
            val current = checkNotNull(session) { "Recitation session is no longer active." }
            val service = checkNotNull(instance) { "Recitation service is no longer active." }
            check(current.ready) { "Recitation service is not ready." }
            current.muted = muted
            service.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, service.buildNotification(current))
        }

        internal fun dispatch(sessionId: String?, action: String?) {
            val current = session ?: return
            if (sessionId != current.id || !current.ready || current.hangingUp) return
            if (action != TOGGLE_MUTE && action != HANG_UP) return
            if (action == HANG_UP) current.hangingUp = true
            // Dart must save/stop recording before it calls our stop method.
            current.onAction(action)
        }

        internal fun stop(context: Context) {
            session = null
            instance?.let {
                it.removeNotification()
                it.stopSelf()
            }
            instance = null
            context.stopService(Intent(context, RecitationCallService::class.java))
        }
    }
}
