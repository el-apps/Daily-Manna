import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/bytes_audio_source.dart';
import 'package:daily_manna/wav_encoder.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_confirmation_dialog.dart';
import 'package:daily_manna/recitation_results.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/settings_service.dart';
import 'package:daily_manna/whisper_service.dart';
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
   List<int>? _audioBytes;
   Stream<Uint8List>? _audioStream;
   final List<List<int>> _audioChunks = [];

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
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
    _audioPlayer.dispose();
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
        
        // Clear previous chunks
        _audioChunks.clear();
        
        // Record to stream on all platforms
        _audioStream = await _recorder.startStream(config);
        
        // Listen to stream and collect chunks
        _audioStream!.listen((chunk) {
          _audioChunks.add(chunk);
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
      debugPrint('[RecitationMode] Expected duration at 16kHz: ${_audioBytes!.length / (16000 * 2)} seconds');
      
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

    debugPrint('[RecitationMode] Starting audio processing');
    _showLoadingDialog('Transcribing audio...');

    try {
      // Encode PCM to WAV format
      debugPrint('[RecitationMode] Encoding PCM to WAV');
      final wavData = WavEncoder.encodePcm16ToWav(
        audioBytes.toList(),
        sampleRate: 16000,
      );
      debugPrint('[RecitationMode] WAV encoded, size: ${wavData.length} bytes');
      
      // Transcribe audio
      debugPrint('[RecitationMode] Calling Whisper transcription');
      final transcribedText = await _whisperService.transcribeAudioBytes(wavData, 'audio.wav');
      Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      debugPrint('[RecitationMode] Got transcribed text: "$transcribedText"');

      _showLoadingDialog('Recognizing passage...');

      // Recognize passage
      debugPrint('[RecitationMode] Calling passage recognition');
      final recognitionResult = await _openRouterService.recognizePassage(transcribedText);
      debugPrint('[RecitationMode] Got recognition result: ${recognitionResult.book}');
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
              debugPrint('[RecitationMode] User confirmed passage: ${ref.bookId}');
              _showRecitationResults(ref, transcribedText);
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('[RecitationMode] Error in recording processing: $e');
      if (mounted) Navigator.pop(context); // Close loading dialog
      _showError('Error: $e');
    }
  }

  void _showRecitationResults(ScriptureRef ref, String transcribedText) {
    _showLoadingDialog('Grading recitation...');

    // Small delay to ensure dialog is visible
    Future.delayed(Duration.zero, () async {
      try {
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

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog

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
                  _audioBytes = null;
                  _audioStream = null;
                  _audioChunks.clear();
                });
              },
            ),
          ),
        );
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showError('Error grading recitation: $e');
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recite')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isPlayingBack) ...[
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
            ] else
              // Playback section
              _buildPlaybackSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review Your Recording',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.music_note,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              StreamBuilder<PlayerState>(
                stream: _audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;

                  return Column(
                    children: [
                      // Playback progress
                      StreamBuilder<Duration?>(
                        stream: _audioPlayer.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = _audioPlayer.duration ?? Duration.zero;
                          
                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  min: 0,
                                  max: duration.inMilliseconds.toDouble(),
                                  value: position.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    _audioPlayer.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // Play/Pause button
                      FilledButton.icon(
                        onPressed: _togglePlayback,
                        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(isPlaying ? 'Pause' : 'Play'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _discardRecording,
                      icon: const Icon(Icons.delete),
                      label: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sendForTranscription,
                      icon: const Icon(Icons.check),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
