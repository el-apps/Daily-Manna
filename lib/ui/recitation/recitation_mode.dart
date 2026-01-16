import 'package:flutter/foundation.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/ui/recitation/results/recitation_results.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:daily_manna/bytes_audio_source.dart';
import 'package:daily_manna/wav_encoder.dart';
import 'package:daily_manna/services/openrouter_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'package:daily_manna/services/whisper_service.dart';
import 'package:daily_manna/ui/recitation/recitation_playback_section.dart';
import 'package:daily_manna/ui/recitation/recitation_confirmation_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:word_tools/word_tools.dart';
import 'package:just_audio/just_audio.dart';

class RecitationMode extends StatefulWidget {
  const RecitationMode({super.key});

  @override
  State<RecitationMode> createState() => _RecitationModeState();
}

class _RecitationModeState extends State<RecitationMode> {
  late AudioRecorder _recorder;
  late AudioPlayer _audioPlayer;
  late SettingsService _settingsService;
  late WhisperService _whisperService;
  late OpenRouterService _openRouterService;

  bool _isRecording = false;
  bool _isPlayingBack = false;
  bool _isConfirmingPassage = false;
  bool _isTranscribing = false;
  bool _isRecognizing = false;
  String _loadingMessage = '';
  List<int>? _audioBytes;
  Stream<Uint8List>? _audioStream;
  final List<List<int>> _audioChunks = [];
  String _transcribedText = '';
  late ScriptureRangeRef _selectedPassageRef;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _settingsService = context.read<SettingsService>();
    _whisperService = WhisperService(_settingsService);
    _openRouterService = OpenRouterService(_settingsService);
    _selectedPassageRef = ScriptureRangeRef(
      bookId: '',
      startChapter: 1,
      startVerse: 1,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeys();
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _checkApiKeys() {
    if (!_settingsService.hasRequiredKeys()) {
      _showMissingKeysError();
    }
  }

  void _handleError(String message, {String? context}) {
    if (context != null) {
      debugPrint('[RecitationMode] Error ($context): $message');
    }
    _showError(message);
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

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final config = const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        );

        debugPrint(
          '[RecitationMode] Recording config: sampleRate=${config.sampleRate}, numChannels=${config.numChannels}, encoder=${config.encoder}',
        );

        // Clear previous chunks
        _audioChunks.clear();

        // Record to stream on all platforms
        _audioStream = await _recorder.startStream(config);

        // Listen to stream and collect chunks
        _audioStream!.listen((chunk) {
          _audioChunks.add(chunk);
          debugPrint(
            '[RecitationMode] Received audio chunk: ${chunk.length} bytes',
          );
        });

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

      if (_audioChunks.isEmpty) {
        _showError('No audio data recorded');
        return;
      }

      // Combine all chunks into single byte array
      _audioBytes = Uint8List.fromList(
        _audioChunks.expand((chunk) => chunk).toList(),
      );

      debugPrint('[RecitationMode] Total PCM bytes: ${_audioBytes!.length}');
      debugPrint(
        '[RecitationMode] Expected duration at 16kHz: ${_audioBytes!.length / (16000 * 2)} seconds',
      );

      // Load audio for playback
      final wavData = WavEncoder.encodePcm16ToWav(
        _audioBytes!.toList(),
        sampleRate: 16000,
      );
      debugPrint('[RecitationMode] WAV file size: ${wavData.length} bytes');
      final audioSource = await createBytesAudioSource(wavData);
      await _audioPlayer.setAudioSource(audioSource);

      // Show playback UI
      setState(() => _isPlayingBack = true);
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _processRecording() async {
    final audioBytes = _audioBytes;
    if (audioBytes == null) return;

    setState(() {
      _isTranscribing = true;
      _loadingMessage = 'Transcribing audio...';
    });

    try {
      final wavData = WavEncoder.encodePcm16ToWav(
        audioBytes.toList(),
        sampleRate: 16000,
      );

      final transcribedText = await _whisperService.transcribeAudioBytes(
        wavData,
        'audio.wav',
      );

      if (!mounted) return;
      _transcribedText = transcribedText;

      setState(() {
        _isTranscribing = false;
        _isRecognizing = true;
        _loadingMessage = 'Recognizing passage...';
      });

      final bibleService = context.read<BibleService>();
      final recognizedRef = await _openRouterService.recognizePassage(
        transcribedText,
        availableBookIds: bibleService.books.map((b) => b.id).toList(),
      );

      if (!mounted) return;

      if (recognizedRef == null) {
        _handleError('Could not recognize passage from your recitation.');
        return;
      }

      setState(() {
        _isRecognizing = false;
        _selectedPassageRef = recognizedRef;
        _isConfirmingPassage = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _isRecognizing = false;
      });
      _handleError(
        'Something went wrong processing your recitation. Please try again.',
      );
    }
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
        passageRef.startChapter,
        passageRef.startVerse,
        endChapter: passageRef.endChapter,
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
                _audioBytes = null;
                _audioStream = null;
                _audioChunks.clear();
                _isConfirmingPassage = false;
                _transcribedText = '';
              });
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Error grading recitation: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _togglePlayback() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      _showError('Playback error: $e');
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      _showError('Error stopping playback: $e');
    }
  }

  Future<void> _sendForTranscription() async {
    await _stopPlayback();
    setState(() => _isPlayingBack = false);
    await _processRecording();
  }

  Future<void> _discardRecording() async {
    await _stopPlayback();
    setState(() {
      _isPlayingBack = false;
      _audioBytes = null;
      _audioStream = null;
      _audioChunks.clear();
    });
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
    setState(() {
      _isConfirmingPassage = false;
    });
    _showRecitationResults(_selectedPassageRef, _transcribedText);
  }

  void _cancelConfirmation() {
    setState(() {
      _isConfirmingPassage = false;
      _transcribedText = '';
      _audioBytes = null;
      _audioStream = null;
      _audioChunks.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recite')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isTranscribing || _isRecognizing)
            _buildLoadingSection()
          else if (_isConfirmingPassage)
            RecitationConfirmationSection(
              passageRef: _selectedPassageRef,
              onPassageSelected: (ref) {
                setState(() => _selectedPassageRef = ref);
              },
              onConfirm: _confirmPassage,
              onCancel: _cancelConfirmation,
            )
          else if (!_isPlayingBack) ...[
            // Recording section
            ThemeCard(
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
                    label: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                    ),
                  ),
                ],
              ),
            ),
          ] else
            RecitationPlaybackSection(
              audioPlayer: _audioPlayer,
              onTogglePlayback: _togglePlayback,
              onStopPlayback: _stopPlayback,
              onDiscard: _discardRecording,
              onSubmit: _sendForTranscription,
            ),
        ],
      ),
    ),
  );

  Widget _buildLoadingSection() => ThemeCard(
    child: Column(
      spacing: 24,
      children: [
        const SizedBox(height: 4),
        const CircularProgressIndicator(),
        Text(
          _loadingMessage,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );


}
