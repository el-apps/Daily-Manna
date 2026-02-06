import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/openrouter_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/loading_section.dart';
import 'package:daily_manna/ui/recitation/recitation_confirmation_section.dart';
import 'package:daily_manna/ui/recitation/recitation_playback_section.dart';
import 'package:daily_manna/ui/recitation/recitation_results.dart';
import 'package:daily_manna/ui/recitation/recording_card.dart';
import 'package:daily_manna/ui/recitation/transcription_review_section.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:word_tools/word_tools.dart';

enum RecitationStep {
  idle,
  recording,
  playback,
  transcribing,
  transcriptionReview,
  recognizing,
  referenceReview,
}

class RecitationMode extends StatefulWidget {
  const RecitationMode({super.key});

  @override
  State<RecitationMode> createState() => _RecitationModeState();
}

class _RecitationModeState extends State<RecitationMode> {
  late AudioRecorder _recorder;
  late AudioPlayer _audioPlayer;
  late SettingsService _settingsService;
  late OpenRouterService _openRouterService;

  RecitationStep _step = RecitationStep.idle;
  String? _audioFilePath;
  Uint8List? _audioData;
  Duration? _audioDuration;
  late TextEditingController _transcriptionController;
  late ScriptureRangeRef _selectedPassageRef;

  // Max chunk size for API limits (at 64kbps, 4 min ≈ 1.9MB)
  static const _maxChunkBytes = 2 * 1024 * 1024; // 2MB

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _settingsService = context.read<SettingsService>();
    _openRouterService = OpenRouterService(_settingsService);
    _transcriptionController = TextEditingController();
    _selectedPassageRef = ScriptureRangeRef(
      bookId: '',
      chapter: 1,
      startVerse: 1,
    );

    // Keep screen on during recitation flow
    WakelockPlus.enable();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeys();
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _clearAudio();
    _recorder.dispose();
    _audioPlayer.dispose();
    _transcriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Recite',
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (_step) {
            RecitationStep.transcribing => LoadingSection(
              message: 'Transcribing audio...',
            ),
            RecitationStep.transcriptionReview => TranscriptionReviewSection(
              controller: _transcriptionController,
              onSubmit: _submitTranscription,
              onCancel: _cancelTranscriptionReview,
            ),
            RecitationStep.recognizing => LoadingSection(
              message: 'Recognizing passage...',
            ),
            RecitationStep.referenceReview => RecitationConfirmationSection(
              passageRef: _selectedPassageRef,
              onPassageSelected: (ref) {
                setState(() => _selectedPassageRef = ref);
              },
              onConfirm: _confirmPassage,
              onCancel: _cancelReferenceReview,
            ),
            RecitationStep.playback => RecitationPlaybackSection(
              audioPlayer: _audioPlayer,
              onTogglePlayback: _togglePlayback,
              onStopPlayback: _stopPlayback,
              onDiscard: _discardRecording,
              onSubmit: _sendForTranscription,
            ),
            RecitationStep.idle || RecitationStep.recording => RecordingCard(
              state: _step == RecitationStep.recording
                  ? RecordingState.recording
                  : RecordingState.idle,
              onToggle: _step == RecitationStep.recording
                  ? _stopRecording
                  : _startRecording,
            ),
          },
        ],
      ),
    ),
  );

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        _clearAudio();

        // Use Opus compression - smaller files and Gemini-compatible
        final config = const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        );

        final tempDir = await getTemporaryDirectory();
        _audioFilePath = '${tempDir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.opus';

        debugPrint('[RecitationMode] Starting recording at $_audioFilePath');
        await _recorder.start(config, path: _audioFilePath!);

        setState(() => _step = RecitationStep.recording);
      } else {
        _safeShowError('Microphone permission denied');
      }
    } catch (e) {
      _safeShowError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (path == null || path.isEmpty) {
        _safeShowError('No audio data recorded');
        return;
      }

      _audioFilePath = path;
      final file = File(_audioFilePath!);
      _audioData = await file.readAsBytes();

      debugPrint('[RecitationMode] AAC file size: ${_audioData!.length} bytes');

      // Set up audio player with the recorded file
      await _audioPlayer.setFilePath(_audioFilePath!);
      _audioDuration = _audioPlayer.duration;
      debugPrint('[RecitationMode] Duration: ${_audioDuration?.inSeconds}s');

      if (!mounted) return;
      setState(() => _step = RecitationStep.playback);
    } catch (e) {
      if (!mounted) return;
      _safeShowError('Failed to stop recording: $e');
    }
  }

  /// Split audio data into chunks under the size limit
  List<Uint8List> _chunkAudioData(Uint8List data) {
    if (data.length <= _maxChunkBytes) {
      return [data];
    }

    final chunks = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + _maxChunkBytes).clamp(0, data.length);
      chunks.add(Uint8List.sublistView(data, offset, end));
      offset = end;
    }
    debugPrint('[RecitationMode] Split ${data.length} bytes into ${chunks.length} chunks');
    return chunks;
  }

  Future<void> _transcribeAudio() async {
    if (!mounted) return;

    setState(() => _step = RecitationStep.transcribing);

    final audioData = _audioData!;
    final totalSize = audioData.length;
    final audioDuration = _audioDuration?.inSeconds.toDouble() ?? 0;
    
    // Split into chunks if needed for API limits
    final chunks = _chunkAudioData(audioData);
    final chunkCount = chunks.length;

    context.read<ErrorLoggerService>().logInfo(
      'AAC: ${(totalSize / 1024).toStringAsFixed(1)} KB, '
      'chunks: $chunkCount, '
      'duration: ${audioDuration.toStringAsFixed(1)}s, '
      'model: ${OpenRouterService.transcriptionModel}',
      context: 'transcription_start',
    );

    try {
      // Transcribe each chunk and concatenate results
      final transcriptions = <String>[];
      
      for (var i = 0; i < chunks.length; i++) {
        debugPrint('[RecitationMode] Transcribing chunk ${i + 1}/$chunkCount (${chunks[i].length} bytes)');
        final chunkText = await _openRouterService
            .transcribeAudio(chunks[i], 'audio.opus');
        transcriptions.add(chunkText.trim());
        
        if (!mounted) return;
      }

      final transcribedText = transcriptions.join(' ');
      debugPrint('[RecitationMode] Combined transcription: ${transcribedText.length} chars');

      if (!mounted) return;
      _transcriptionController.text = transcribedText;
      setState(() => _step = RecitationStep.transcriptionReview);
    } on TimeoutException catch (e, st) {
      if (!mounted) return;
      setState(() => _step = RecitationStep.playback);
      _handleError(
        'Your connection is too slow to upload the recording. '
        'Please try again with a stronger internet connection.',
        context: 'transcription_timeout',
        errorDetails:
            'TimeoutException after ${OpenRouterService.transcriptionTimeout.inSeconds}s\n'
            'Audio size: $totalSize bytes (AAC), '
            'Duration: ${audioDuration.toStringAsFixed(1)}s\n'
            '$e\n$st',
      );
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _step = RecitationStep.playback);

      final errorStr = e.toString();
      String msg;
      if (errorStr.contains('OpenRouter API key not configured')) {
        msg = 'OpenRouter API key is not configured. Please update it in Settings, then try again.';
      } else {
        msg = 'Something went wrong transcribing your recitation. Check Settings > Logs for details.';
      }

      _handleError(
        msg,
        context: 'transcription',
        errorDetails:
            'Audio size: $totalSize bytes (AAC), '
            'Chunks: $chunkCount, '
            'Duration: ${audioDuration.toStringAsFixed(1)}s\n'
            '$e\n$st',
      );
    }
  }

  Future<void> _recognizePassage() async {
    if (!mounted) return;

    setState(() => _step = RecitationStep.recognizing);

    final bibleService = context.read<BibleService>();
    if (!bibleService.isLoaded) {
      if (!mounted) return;
      setState(() => _step = RecitationStep.transcriptionReview);
      _handleError(
        'Bible data is still loading. Please try again in a moment.',
        context: 'recognition',
      );
      return;
    }

    final transcribedText = _transcriptionController.text;

    try {
      final recognizedRef = await _openRouterService
          .recognizePassage(
            transcribedText,
            availableBookIds: bibleService.books.map((b) => b.id).toList(),
          );

      if (!mounted) return;

      if (recognizedRef == null) {
        setState(() => _step = RecitationStep.referenceReview);
        _handleError(
          'Could not recognize passage. Please enter it manually.',
          context: 'recognition',
        );
        return;
      }

      setState(() {
        _selectedPassageRef = recognizedRef;
        _step = RecitationStep.referenceReview;
      });
    } on TimeoutException catch (e, st) {
      if (!mounted) return;
      setState(() => _step = RecitationStep.transcriptionReview);
      _handleError(
        'Your connection is too slow. Please try again with a stronger internet connection.',
        context: 'recognition_timeout',
        errorDetails:
            'TimeoutException after ${OpenRouterService.recognitionTimeout.inSeconds}s\n'
            'Transcription length: ${transcribedText.length} chars\n'
            '$e\n$st',
      );
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _step = RecitationStep.transcriptionReview);
      _handleError(
        'Something went wrong recognizing the passage. Check Settings > Logs for details.',
        context: 'recognition',
        errorDetails:
            'Transcription length: ${transcribedText.length} chars\n'
            '$e\n$st',
      );
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      _safeShowError('Playback error: $e');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      _safeShowError('Error stopping playback: $e');
    }
  }

  Future<void> _sendForTranscription() async {
    await _stopPlayback();
    await _transcribeAudio();
  }

  void _submitTranscription() {
    _recognizePassage();
  }

  void _cancelTranscriptionReview() {
    if (mounted) {
      setState(() => _step = RecitationStep.playback);
    }
  }

  void _cancelReferenceReview() {
    if (mounted) {
      setState(() => _step = RecitationStep.transcriptionReview);
    }
  }

  Future<void> _discardRecording() async {
    await _stopPlayback();
    if (mounted) {
      setState(() {
        _step = RecitationStep.idle;
        _clearAudio();
      });
    }
  }

  void _confirmPassage() {
    if (!_selectedPassageRef.complete) {
      _showError('Please select a valid passage');
      return;
    }

    final bibleService = context.read<BibleService>();
    debugPrint(
      '[RecitationMode] User confirmed passage: ${bibleService.getRangeRefName(_selectedPassageRef)}',
    );
    _showRecitationResults(_selectedPassageRef, _transcriptionController.text);
  }

  void _showRecitationResults(
    ScriptureRangeRef passageRef,
    String transcribedText,
  ) {
    // Compute score synchronously and navigate immediately
    try {
      final bibleService = context.read<BibleService>();

      // Get the actual passage (handles single verse or range)
      String actualPassage = bibleService.getPassageRange(
        passageRef.bookId,
        passageRef.chapter,
        passageRef.startVerse,
        endVerse: passageRef.endVerse,
      );

      // Grade the recitation
      final score = compareWordSequences(actualPassage, transcribedText);

      // Add result to service
      final resultsService = context.read<ResultsService>();
      resultsService.addRecitationResult(
        RecitationResult(ref: passageRef, score: score),
      );

      // Navigate to results page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecitationResults(
            ref: passageRef,
            transcribedText: transcribedText,
            score: score,
            onReciteAgain: () {
              Navigator.of(context).pop(); // Pop results page
              setState(() {
                _step = RecitationStep.idle;
                _clearAudio();
                _transcriptionController.clear();
              });
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Error grading recitation: $e');
    }
  }

  void _clearAudio() {
    // Clean up temp file
    if (_audioFilePath != null) {
      File(_audioFilePath!).delete().ignore();
    }
    _audioFilePath = null;
    _audioData = null;
    _audioDuration = null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _safeShowError(String message) {
    if (!mounted) return;
    _showError(message);
  }

  void _handleError(String message, {String? context, String? errorDetails}) {
    if (context != null) {
      debugPrint('[RecitationMode] Error ($context): $message');
    }
    if (errorDetails != null && mounted) {
      try {
        final errorLoggerService = this.context.read<ErrorLoggerService>();
        errorLoggerService.logError(errorDetails, context: context);
      } catch (_) {
        // Ignore if logger service is not available
      }
    }
    _showError(message);
  }

  void _checkApiKeys() {
    if (!_settingsService.hasRequiredKeys()) {
      _showMissingKeysError();
    }
  }

  void _showMissingKeysError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('API Keys Required'),
        content: const Text(
          'Please configure your OpenRouter API key in Settings before using Recitation Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }
}
