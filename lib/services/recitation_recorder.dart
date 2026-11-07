import 'dart:async';

import 'package:daily_manna/recording_platform.dart';
import 'package:daily_manna/services/recitation_audio_input.dart';
import 'package:daily_manna/services/recitation_call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

enum RecitationRecordingState {
  idle,
  starting,
  recording,
  muted,
  stopping,
  saved,
}

/// Serializes screen and notification actions against the same recording.
class RecitationRecorder extends ChangeNotifier {
  RecitationRecorder({
    AudioRecorder? recorder,
    RecitationCallService? callService,
    RecitationAudioInput? audioInput,
    Future<String> Function()? pathProvider,
  }) : _recorder = recorder ?? AudioRecorder(),
       _callService = callService ?? RecitationCallService(),
       _audioInput = audioInput ?? RecitationAudioInput(),
       _pathProvider = pathProvider ?? recordingPath {
    _subscription = _recorder.onStateChanged().listen(
      (_) => unawaited(_run(_refreshState)),
      onError: (Object error) => unawaited(
        _run(() async {
          if (!isRecording) return;
          await _stop();
          _error = 'Recording interrupted: $error';
          _notify();
        }),
      ),
    );
  }

  final AudioRecorder _recorder;
  final RecitationCallService _callService;
  final RecitationAudioInput _audioInput;
  final Future<String> Function() _pathProvider;
  late final StreamSubscription<RecordState> _subscription;
  Future<void> _pending = Future.value();
  Future<void>? _closeFuture;
  bool _closing = false;
  bool _changingMute = false;
  bool _loadingInputs = false;
  List<RecitationInput> _inputs = const [RecitationInput.phone];
  List<RecitationInput> get inputs => List.unmodifiable(_inputs);
  RecitationInput _selectedInput = RecitationInput.phone;
  RecitationInput get selectedInput => _selectedInput;
  bool get supportsInputSelection => _audioInput.isSupported;
  bool get loadingInputs => _loadingInputs;
  bool get inputAvailable =>
      !supportsInputSelection ||
      _inputs.any((input) => input.id == _selectedInput.id);

  RecitationRecordingState _state = RecitationRecordingState.idle;
  RecitationRecordingState get state => _state;
  String? _path;
  String? get path => _path;
  String? _error;
  String? get error => _error;
  bool get isMuted => state == RecitationRecordingState.muted;
  bool get isRecording =>
      state == RecitationRecordingState.recording || isMuted;
  bool get isBusy =>
      state == RecitationRecordingState.starting ||
      state == RecitationRecordingState.stopping ||
      _loadingInputs ||
      _changingMute;

  Future<void> _run(Future<void> Function() operation) {
    final next = _pending.then((_) async {
      if (!_closing) await operation();
    });
    _pending = next;
    return next;
  }

  void _notify() {
    if (!_closing) notifyListeners();
  }

  Future<void> refreshInputs() => _run(() async {
    if (!supportsInputSelection || isRecording) return;
    _loadingInputs = true;
    _error = null;
    _notify();
    try {
      _inputs = await _audioInput.list();
    } catch (error) {
      _error = 'Failed to list microphones: $error';
    } finally {
      _loadingInputs = false;
      _notify();
    }
  });

  void selectInput(String id) {
    if (_closing || isRecording || isBusy) return;
    final matching = _inputs.where((input) => input.id == id);
    if (matching.isEmpty) return;
    _selectedInput = matching.first;
    _error = null;
    _notify();
  }

  Future<void> start() => _run(() async {
    if (isRecording) return;
    _state = RecitationRecordingState.starting;
    _error = null;
    _path = null;
    _notify();
    try {
      if (!await _recorder.hasPermission()) {
        throw StateError('Microphone permission denied');
      }
      if (_closing) return;
      final path = kIsWeb ? '' : await _pathProvider();
      if (_closing) return;
      // Enter the foreground while the activity is visible, before capturing.
      await _callService.start(onToggleMute: toggleMute, onHangUp: stop);
      if (_closing) return;
      final device = await _audioInput.prepare(
        _selectedInput,
        onLost: (message) => _run(() async {
          if (!isRecording) return;
          await _stop();
          _error = _path != null
              ? '$message Recording stopped. Review the saved audio.'
              : '$message ${_error ?? 'No audio was saved.'}';
          _notify();
        }),
      );
      if (_closing) return;
      final bluetooth = supportsInputSelection && _selectedInput.bluetooth;
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          device: device,
          androidConfig: AndroidRecordConfig(
            // Native routing owns the choice; the plugin must not auto-switch.
            manageBluetooth: !supportsInputSelection,
            audioSource: bluetooth
                ? AndroidAudioSource.voiceCommunication
                : AndroidAudioSource.mic,
            audioManagerMode: bluetooth
                ? AudioManagerMode.modeInCommunication
                : AudioManagerMode.modeNormal,
          ),
        ),
        path: path,
      );
      await _audioInput.verify();
      _state = RecitationRecordingState.recording;
    } catch (error) {
      await _cancel();
      _state = RecitationRecordingState.idle;
      _error = 'Failed to start recording: $error';
    }
    _notify();
  });

  Future<void> toggleMute() => _run(() async {
    if (!isRecording) return;
    _changingMute = true;
    _error = null;
    _notify();
    try {
      if (isMuted) {
        await _recorder.resume();
      } else {
        // Pause excludes muted speech from the saved WAV and transcription.
        await _recorder.pause();
      }
      await _refreshState();
    } catch (error) {
      _error = 'Failed to change microphone state: $error';
    } finally {
      _changingMute = false;
      _notify();
    }
  });

  Future<void> _refreshState() async {
    if (!isRecording) return;
    try {
      if (!await _recorder.isRecording()) {
        await _stop();
        return;
      }
      _state = await _recorder.isPaused()
          ? RecitationRecordingState.muted
          : RecitationRecordingState.recording;
      await _callService.update(muted: isMuted);
      _notify();
    } catch (error) {
      // Never leave recording running with stale or unusable native controls.
      await _stop();
      _error = 'Recitation controls stopped working: $error';
      _notify();
    }
  }

  Future<void> stop() => _run(_stop);

  Future<void> _stop() async {
    if (!isRecording) return;
    _state = RecitationRecordingState.stopping;
    _error = null;
    _notify();
    try {
      _path = await _recorder.stop();
      if (_path == null || _path!.isEmpty) {
        throw StateError('No audio data recorded');
      }
      _state = RecitationRecordingState.saved;
    } catch (error) {
      await _cancel();
      _path = null;
      _state = RecitationRecordingState.idle;
      _error = 'Failed to stop recording: $error';
    } finally {
      try {
        await _audioInput.release();
      } catch (error) {
        _error = 'Failed to release microphone: $error';
      } finally {
        try {
          await _callService.stop();
        } catch (error) {
          _error = 'Failed to close recitation controls: $error';
        }
      }
    }
    _notify();
  }

  Future<void> _cancel() async {
    try {
      // Android cancel returns before its capture thread restores audio mode.
      // Drain an active recorder first so late cleanup cannot undo route release.
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {
      // Still attempt cancellation if the recorder has already failed.
    }
    try {
      await _recorder.cancel();
    } catch (_) {
      // A failed start may not have created a recorder yet.
    } finally {
      try {
        await _audioInput.release();
      } catch (_) {
        // Native lifecycle cleanup also releases routing.
      } finally {
        try {
          await _callService.stop();
        } catch (_) {
          // Native startup failures also tear down their service.
        }
      }
    }
  }

  /// Waits for in-flight permission/start actions before releasing resources.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closing = true;
    await _pending;
    await _subscription.cancel();
    // Also discard a file finished after the screen began disposing.
    await _cancel();
    try {
      await _recorder.dispose();
    } finally {
      await _callService.stop();
    }
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object error) {
        debugPrint('Failed to release recitation recorder: $error');
      }),
    );
    super.dispose();
  }
}
