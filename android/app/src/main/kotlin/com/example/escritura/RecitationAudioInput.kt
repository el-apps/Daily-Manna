package com.github.el_apps.daily_manna

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRouting
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import com.llfbandit.record.RecordPlugin
import com.llfbandit.record.methodcall.MethodCallHandlerImpl
import com.llfbandit.record.record.recorder.AudioRecorder as PluginAudioRecorder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Routing only: Dart owns starting/stopping capture and must release AFTER recorder.stop/cancel. */
@Suppress("DEPRECATION")
class RecitationAudioInput(context: Context, private val engine: FlutterEngine) {
    private val context = context.applicationContext
    private val audio = this.context.getSystemService(AudioManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "daily_manna/recitation_input")
    private data class Selection(val id: String, val label: String, val device: AudioDeviceInfo?)
    private var selected: Selection? = null
    private var input: AudioDeviceInfo? = null
    private var recorder: AudioRecord? = null
    private var pluginRecorder: PluginAudioRecorder? = null
    private var restoreRecorderMode: (() -> Unit)? = null
    private var previousMode: Int? = null
    private var prepareResult: MethodChannel.Result? = null
    private var verifyResult: MethodChannel.Result? = null
    private var deadline = 0L
    private var verified = false
    private var lost = false
    private var generation = 0
    private var deviceCallback: AudioDeviceCallback? = null
    private var communicationListener: AudioManager.OnCommunicationDeviceChangedListener? = null
    private var scoReceiver: BroadcastReceiver? = null
    private var scoStarted = false
    private var scoConnected = false
    private var routingListener: AudioRouting.OnRoutingChangedListener? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> try {
                    result.success(choices().map {
                        mapOf("id" to it.id, "label" to it.label, "bluetooth" to (it.id != PHONE))
                    })
                } catch (error: RuntimeException) {
                    result.error("input_unavailable", error.message, null)
                }
                "prepare" -> {
                    val id = (call.arguments as? Map<*, *>)?.get("id") as? String
                    if (id == null) result.error("invalid_arguments", "id must be a string.", null)
                    else prepare(id, result)
                }
                "verify" -> verify(result)
                "release" -> { release(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun isHeadset(device: AudioDeviceInfo): Boolean =
        device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
            (Build.VERSION.SDK_INT >= 31 && device.type == AudioDeviceInfo.TYPE_BLE_HEADSET)

    private fun choices(): List<Selection> {
        val devices = if (Build.VERSION.SDK_INT >= 31) audio.availableCommunicationDevices
        else audio.getDevices(AudioManager.GET_DEVICES_INPUTS).toList()
        return listOf(Selection(PHONE, "Phone microphone", null)) + devices.filter(::isHeadset).map {
            val kind = if (it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) "Bluetooth" else "Bluetooth LE"
            Selection("bluetooth:${it.id}", "$kind microphone · ${it.productName}", it)
        }
    }

    private fun prepare(id: String, result: MethodChannel.Result) {
        if (selected != null) {
            result.error("input_busy", "Release the previous input before selecting another.", null)
            return
        }
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.error("permission_denied", "Microphone permission is required.", null)
            return
        }
        prepareResult = result
        try {
            val choice = choices().firstOrNull { it.id == id }
            if (choice == null) {
                prepareResult = null
                result.error("input_unavailable", "The selected microphone is no longer available.", null)
                return
            }
            selected = choice
            previousMode = audio.mode
            deadline = SystemClock.elapsedRealtime() + PREPARE_TIMEOUT
            registerCallbacks()
            if (id == PHONE) {
                // record_android does not actually assign MODE_NORMAL when it is requested.
                if (Build.VERSION.SDK_INT >= 31) audio.clearCommunicationDevice()
                else audio.isBluetoothScoOn = false
                audio.mode = AudioManager.MODE_NORMAL
            } else {
                audio.mode = AudioManager.MODE_IN_COMMUNICATION
                if (Build.VERSION.SDK_INT >= 31) {
                    check(audio.setCommunicationDevice(checkNotNull(choice.device))) {
                        "Android rejected the selected Bluetooth microphone."
                    }
                } else {
                    check(audio.isBluetoothScoAvailableOffCall) { "Bluetooth microphone recording is not supported on this phone." }
                    scoStarted = true
                    audio.startBluetoothSco()
                    audio.isBluetoothScoOn = true
                }
            }
            checkState()
        } catch (error: RuntimeException) {
            failPreparation(error.message ?: "Unable to select microphone.")
        }
    }

    private fun registerCallbacks() {
        val token = ++generation
        deviceCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                if (token == generation) checkState()
            }
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                if (token != generation) return
                val ids = removedDevices.map { it.id }
                if (input?.id in ids || selected?.device?.id in ids) {
                    unavailable("The selected microphone was disconnected.")
                } else checkState()
            }
        }.also { audio.registerAudioDeviceCallback(it, handler) }
        if (Build.VERSION.SDK_INT >= 31) {
            communicationListener = AudioManager.OnCommunicationDeviceChangedListener {
                if (token == generation) checkState()
            }.also { audio.addOnCommunicationDeviceChangedListener({ command -> handler.post(command) }, it) }
        } else {
            scoReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (token != generation) return
                    scoConnected = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ==
                        AudioManager.SCO_AUDIO_STATE_CONNECTED
                    checkState()
                }
            }.also {
                context.registerReceiver(it, IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED))
            }
        }
    }

    private fun resolveInput(choice: Selection): AudioDeviceInfo? {
        val inputs = audio.getDevices(AudioManager.GET_DEVICES_INPUTS).filter { it.isSource }
        if (choice.id == PHONE) return inputs.filter { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }.minByOrNull { it.id }
        val output = checkNotNull(choice.device)
        val candidates = inputs.filter { it.type == output.type }
        if (Build.VERSION.SDK_INT < 31) return candidates.firstOrNull { it.id == output.id }
        // Sink and source IDs differ. Never guess between two headsets with the same type/name.
        val address = output.address
        if (address.isNotEmpty()) {
            val matches = candidates.filter { it.address == address }
            if (matches.size == 1) return matches.single()
            if (candidates.any { it.address.isNotEmpty() }) return null
        }
        val outputs = audio.availableCommunicationDevices.filter { it.type == output.type }
        return candidates.singleOrNull()?.takeIf { outputs.size == 1 }
    }

    private fun communicationReady(choice: Selection): Boolean = choice.id == PHONE ||
        if (Build.VERSION.SDK_INT >= 31) audio.communicationDevice?.id == choice.device?.id
        else scoConnected && audio.isBluetoothScoOn

    private fun verify(result: MethodChannel.Result) {
        if (selected == null || prepareResult != null || lost) {
            result.error("input_not_prepared", "Prepare a microphone before verifying recording.", null)
            return
        }
        if (verifyResult != null) {
            result.error("input_busy", "Microphone verification is already in progress.", null)
            return
        }
        if (verified) {
            checkState()
            if (lost) result.error("input_verification_failed", "The selected microphone was lost.", null)
            else result.success(null)
            return
        }
        verifyResult = result
        deadline = SystemClock.elapsedRealtime() + VERIFY_TIMEOUT
        checkState()
    }

    private val poll = Runnable { checkState() }

    private fun checkState() {
        handler.removeCallbacks(poll)
        val choice = selected ?: return
        if (lost) return
        try {
            if (prepareResult != null) {
                val resolved = resolveInput(choice)
                if (resolved != null && communicationReady(choice)) {
                    input = resolved
                    val result = prepareResult
                    prepareResult = null
                    result?.success(mapOf("id" to resolved.id.toString(), "label" to choice.label))
                } else if (SystemClock.elapsedRealtime() >= deadline) {
                    failPreparation("Timed out connecting to ${choice.label}.")
                    return
                }
            } else {
                if (audio.getDevices(AudioManager.GET_DEVICES_INPUTS).none { it.id == input?.id }) {
                    unavailable("${choice.label} is no longer available.")
                    return
                }
                if (verifyResult != null) {
                    if (recorder == null) attachRecorder()
                    if (recorder?.recordingState == AudioRecord.RECORDSTATE_RECORDING &&
                        recorder?.routedDevice?.id == input?.id && communicationReady(choice)) {
                        verified = true
                        val result = verifyResult
                        verifyResult = null
                        result?.success(null)
                    } else if (SystemClock.elapsedRealtime() >= deadline) {
                        val result = verifyResult
                        verifyResult = null
                        lost = true
                        result?.error("input_verification_failed", "Recording did not use ${choice.label}. Stop recording and try again.", null)
                        return
                    }
                } else if (verified) {
                    // A paused/stopped recorder may have no route. Device removal above
                    // still stops the session while muted; polling checks the actual input
                    // again on resume, without automatically selecting a fallback.
                    if (pluginRecorder?.isPaused != true &&
                        recorder?.recordingState == AudioRecord.RECORDSTATE_RECORDING &&
                        (!communicationReady(choice) || recorder?.routedDevice?.id != input?.id)) {
                        unavailable("Recording is no longer using ${choice.label}.")
                        return
                    }
                }
            }
            if (selected != null && !lost) handler.postDelayed(poll, POLL_INTERVAL)
        } catch (error: Exception) {
            unavailable(error.message ?: "Unable to verify the selected microphone.")
        }
    }

    /**
     * record_android 1.4.5 exposes neither its AudioRecord nor its session ID. AudioManager's
     * recording configurations are system-wide and anonymized (including other apps), so a
     * matching configuration is NOT proof that our recorder uses that input. This narrow,
     * fail-closed adapter reads the plugin's own AudioRecord instead. Keep rules preserve these
     * fields in release builds. Recheck this adapter when upgrading record_android.
     */
    private fun attachRecorder() {
        val plugin = engine.plugins.get(RecordPlugin::class.java)
        val wrappers = field(field(plugin, "callHandler"), "recorders") as? Map<*, *> ?: return
        val active = wrappers.values.mapNotNull { wrapper ->
            val nativeRecorder = field(wrapper, "recorder") ?: return@mapNotNull null
            check(nativeRecorder is PluginAudioRecorder) {
                "Microphone verification requires the non-legacy Android recorder."
            }
            val thread = field(nativeRecorder, "recorderThread")
            val reader = field(field(thread, "mPcmReader"), "reader") as? AudioRecord
            reader?.takeIf { it.recordingState == AudioRecord.RECORDSTATE_RECORDING }?.let { nativeRecorder to it }
        }
        check(active.size <= 1) { "Stop other app recordings before starting recitation." }
        val (nativeRecorder, capture) = active.singleOrNull() ?: return
        // The plugin snapshots mode only once, in its constructor, then restores it on
        // every pause/stop. A reused recorder must not undo this session's Bluetooth mode
        // when muted. Our release restores the original mode AFTER capture stops.
        val modeField = nativeRecorder.javaClass.getDeclaredField("amPrevAudioMode").apply { isAccessible = true }
        val originalMode = checkNotNull(previousMode)
        restoreRecorderMode = { modeField.setInt(nativeRecorder, originalMode) }
        modeField.setInt(nativeRecorder, if (selected?.id == PHONE) AudioManager.MODE_NORMAL else AudioManager.MODE_IN_COMMUNICATION)
        recorder = capture
        pluginRecorder = nativeRecorder
        val token = generation
        routingListener = AudioRouting.OnRoutingChangedListener {
            if (token == generation) checkState()
        }.also { recorder?.addOnRoutingChangedListener(it, handler) }
    }

    private fun field(owner: Any?, name: String): Any? = owner?.javaClass?.getDeclaredField(name)?.let {
        it.isAccessible = true
        it.get(owner)
    }

    private fun unavailable(message: String) {
        if (prepareResult != null) { failPreparation(message); return }
        if (selected == null || lost) return
        lost = true
        handler.removeCallbacks(poll)
        val result = verifyResult
        verifyResult = null
        result?.error("input_verification_failed", message, null)
        // Keep routing until Dart has stopped/saved. Android may already have fallen back;
        // callbacks/polling cannot guarantee zero frames from an unintended input.
        channel.invokeMethod("inputLost", message)
    }

    private fun failPreparation(message: String) {
        val result = prepareResult
        prepareResult = null
        release()
        result?.error("input_prepare_failed", message, null)
    }

    fun release() {
        ++generation
        handler.removeCallbacksAndMessages(null)
        val preparing = prepareResult
        val verifying = verifyResult
        prepareResult = null
        verifyResult = null
        selected = null
        input = null
        verified = false
        lost = false
        // Cleanup steps are independent: one vendor API failure must not skip the others.
        // Also prevent a later plugin onStop during engine teardown from reviving our mode.
        restoreRecorderMode?.let { runCatching(it) }
        restoreRecorderMode = null
        routingListener?.let { runCatching { recorder?.removeOnRoutingChangedListener(it) } }
        routingListener = null
        recorder = null
        pluginRecorder = null
        deviceCallback?.let { runCatching { audio.unregisterAudioDeviceCallback(it) } }
        deviceCallback = null
        if (Build.VERSION.SDK_INT >= 31) {
            communicationListener?.let { runCatching { audio.removeOnCommunicationDeviceChangedListener(it) } }
            communicationListener = null
            if (previousMode != null) runCatching { audio.clearCommunicationDevice() }
        }
        scoReceiver?.let { runCatching { context.unregisterReceiver(it) } }
        scoReceiver = null
        if (scoStarted) runCatching { audio.stopBluetoothSco() }
        if (Build.VERSION.SDK_INT < 31 && previousMode != null) runCatching { audio.isBluetoothScoOn = false }
        scoStarted = false
        scoConnected = false
        previousMode?.let { mode -> runCatching { audio.mode = mode } }
        previousMode = null
        preparing?.error("input_cancelled", "Microphone preparation was cancelled.", null)
        verifying?.error("input_cancelled", "Microphone verification was cancelled.", null)
    }

    fun resetForEngineRestart() {
        val recorderHandler = if (selected == null) null else runCatching {
            val plugin = engine.plugins.get(RecordPlugin::class.java)
            val delegate = field(plugin, "callHandler") as? MethodCallHandlerImpl
            // A restart can land between record.start and verify, before attachRecorder.
            // Patch that recorder's late mode restoration too, before asking it to stop.
            val wrappers = field(delegate, "recorders") as? Map<*, *>
            previousMode?.let { mode ->
                wrappers?.values?.forEach { wrapper ->
                    val nativeRecorder = field(wrapper, "recorder") as? PluginAudioRecorder
                    nativeRecorder?.javaClass?.getDeclaredField("amPrevAudioMode")?.apply {
                        isAccessible = true
                        setInt(nativeRecorder, mode)
                    }
                }
            }
            delegate
        }.getOrNull()
        release()
        // Dart can no longer stop its recorder after an engine reset. The plugin does
        // not listen for hot restarts itself. Dispose its old wrappers, not the plugin,
        // so a restarted Dart isolate can create fresh recorders on the same channel.
        runCatching { recorderHandler?.dispose() }
    }

    fun dispose() {
        resetForEngineRestart()
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val PHONE = "phone"
        private const val PREPARE_TIMEOUT = 30_000L
        private const val VERIFY_TIMEOUT = 5_000L
        private const val POLL_INTERVAL = 200L
    }
}
