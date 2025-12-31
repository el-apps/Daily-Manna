import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_confirmation_dialog.dart';
import 'package:daily_manna/recitation_results.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:daily_manna/settings_service.dart';
import 'package:daily_manna/whisper_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:word_tools/word_tools.dart';

class RecitationMode extends StatefulWidget {
  const RecitationMode({super.key});

  @override
  State<RecitationMode> createState() => _RecitationModeState();
}

class _RecitationModeState extends State<RecitationMode> {
  late AudioRecorder _recorder;
  late SettingsService _settingsService;
  late WhisperService _whisperService;
  late OpenRouterService _openRouterService;

  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _settingsService = context.read<SettingsService>();
    _whisperService = WhisperService(_settingsService);
    _openRouterService = OpenRouterService(_settingsService);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeys();
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
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
          'Please configure your Whisper and OpenRouter API keys in Settings before using Recitation Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        _recordingPath =
            '${directory.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
          ),
          path: _recordingPath!,
        );

        setState(() => _isRecording = true);
      } else {
        _showError('Microphone permission denied');
      }
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
      setState(() => _isRecording = false);

      if (_recordingPath != null) {
        await _processRecording();
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _processRecording() async {
    if (_recordingPath == null) return;

    _showLoadingDialog('Transcribing audio...');

    try {
      // Transcribe audio
      final transcribedText = await _whisperService.transcribeAudio(_recordingPath!);
      Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      _showLoadingDialog('Recognizing passage...');

      // Recognize passage
      final recognitionResult = await _openRouterService.recognizePassage(transcribedText);
      Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => PassageConfirmationDialog(
          recognitionResult: recognitionResult,
          transcribedText: transcribedText,
          onConfirm: (ref) {
            if (ref != null) {
              _showRecitationResults(ref, transcribedText);
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showError('Error: $e');
    }
  }

  void _showRecitationResults(ScriptureRef ref, String transcribedText) {
    final bibleService = context.read<BibleService>();
    
    // Get the actual verse
    String actualVerse = '';
    if (bibleService.hasVerse(ref)) {
      actualVerse = bibleService.getVerse(
        ref.bookId!,
        ref.chapterNumber!,
        ref.verseNumber!,
      );
    }

    // Grade the recitation
    final score = compareWordSequences(actualVerse, transcribedText);

    // Navigate to results page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RecitationResults(
          ref: ref,
          transcribedText: transcribedText,
          score: score,
          onReciteAgain: () {
            Navigator.of(context).pop(); // Pop results page
            setState(() => _recordingPath = null);
          },
        ),
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Mode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 80,
              color: _isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              _isRecording ? 'Recording...' : 'Ready to recite',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
