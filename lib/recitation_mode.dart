import 'package:daily_manna/audio_helper.dart';
import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_confirmation_dialog.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/recitation_results.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/settings_service.dart';
import 'package:daily_manna/whisper_service.dart';
import 'package:flutter/foundation.dart';
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
   List<int>? _audioBytes;
   Stream<Uint8List>? _audioStream;
   PassageRangeRef _selectedRef = PassageRangeRef(
     bookId: '',
     startChapter: 1,
     startVerse: 1,
   );
   bool _useSelectedPassage = false;

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
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
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
        final config = const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
        );
        
        if (kIsWeb) {
          // On web, record to stream to get bytes directly
          _audioStream = await _recorder.startStream(config);
        } else {
          // On mobile, record to file
          final directory = await getApplicationDocumentsDirectory();
          final recordingPath =
              '${directory.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';
          _recordingPath = recordingPath;
          await _recorder.start(config, path: recordingPath);
        }

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
      if (kIsWeb) {
        // On web, collect stream data
        await _recorder.stop();
        setState(() => _isRecording = false);

        if (_audioStream == null) {
          _showError('Failed to stop recording');
          return;
        }

        final audioDataList = <List<int>>[];
        await for (final chunk in _audioStream!) {
          audioDataList.add(chunk);
        }

        if (audioDataList.isEmpty) {
          _showError('No audio data recorded');
          return;
        }

        // Combine all chunks into single byte array
        _audioBytes = Uint8List.fromList(
          audioDataList.expand((chunk) => chunk).toList(),
        );
        await _processRecording();
      } else {
        // On mobile, read from file
        await _recorder.stop();
        setState(() => _isRecording = false);

        if (_recordingPath == null) {
          _showError('Failed to stop recording');
          return;
        }

        final bytes = await readAudioFile(_recordingPath!);
        if (bytes != null) {
          _audioBytes = bytes;
          await _processRecording();
        } else {
          _showError('Failed to read audio file');
        }
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _processRecording() async {
    final audioBytes = _audioBytes;
    if (audioBytes == null) return;

    _showLoadingDialog('Transcribing audio...');

    try {
      // Transcribe audio
      final filename = 'audio.pcm';
      final transcribedText = await _whisperService.transcribeAudioBytes(audioBytes, filename);
      Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      // If passage was pre-selected, skip recognition step
      if (_useSelectedPassage && _selectedRef.complete) {
        final ref = ScriptureRef(
          bookId: _selectedRef.bookId,
          chapterNumber: _selectedRef.startChapter,
          verseNumber: _selectedRef.startVerse,
        );
        _showRecitationResults(ref, transcribedText);
        return;
      }

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
            setState(() {
              _recordingPath = null;
              _audioBytes = null;
              _audioStream = null;
            });
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
      appBar: AppBar(title: const Text('Recite')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optional passage selector
            Text(
              'Select Passage (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'If you know which passage you\'ll recite, select it here to skip automatic recognition.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            PassageRangeSelector(
              ref: _selectedRef,
              onSelected: (ref) {
                setState(() {
                  _selectedRef = ref;
                  _useSelectedPassage = ref.complete;
                });
              },
            ),
            const SizedBox(height: 32),
            // Recording section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
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
                    label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
