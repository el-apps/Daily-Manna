import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/bytes_audio_source.dart';
import 'package:daily_manna/wav_encoder.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_range_selector.dart';
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
   bool _isConfirmingPassage = false;
   bool _isTranscribing = false;
   bool _isRecognizing = false;
   String _loadingMessage = '';
   List<int>? _audioBytes;
   Stream<Uint8List>? _audioStream;
   final List<List<int>> _audioChunks = [];
   PassageRangeRef? _recognizedPassageRef;
   String _transcribedText = '';
   late PassageRangeRef _selectedPassageRef;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _settingsService = context.read<SettingsService>();
    _whisperService = WhisperService(_settingsService);
    _openRouterService = OpenRouterService(_settingsService);
    _selectedPassageRef = PassageRangeRef(
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
          numChannels: 1,
        );
        
        debugPrint('[RecitationMode] Recording config: sampleRate=${config.sampleRate}, numChannels=${config.numChannels}, encoder=${config.encoder}');
        
        // Clear previous chunks
        _audioChunks.clear();
        
        // Record to stream on all platforms
        _audioStream = await _recorder.startStream(config);
        
        // Listen to stream and collect chunks
        _audioStream!.listen((chunk) {
          _audioChunks.add(chunk);
          debugPrint('[RecitationMode] Received audio chunk: ${chunk.length} bytes');
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
    setState(() {
      _isTranscribing = true;
      _loadingMessage = 'Transcribing audio...';
    });

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

      if (!mounted) return;

      debugPrint('[RecitationMode] Got transcribed text: "$transcribedText"');
      _transcribedText = transcribedText;

      setState(() {
        _isTranscribing = false;
        _isRecognizing = true;
        _loadingMessage = 'Recognizing passage...';
      });

      // Get available book IDs for the LLM
      final bibleService = context.read<BibleService>();
      final availableBookIds = bibleService.books.map((b) => b.id).toList();

      // Recognize passage
      debugPrint('[RecitationMode] Calling passage recognition');
      final recognizedRef = await _openRouterService.recognizePassage(
        transcribedText,
        availableBookIds: availableBookIds,
      );

      if (!mounted) return;

      if (recognizedRef == null) {
        debugPrint('[RecitationMode] Failed to recognize passage');
        _showError('Could not recognize passage');
        return;
      }

      debugPrint('[RecitationMode] Got recognition result: ${recognizedRef.display}');

      setState(() {
        _isRecognizing = false;
        _recognizedPassageRef = recognizedRef;
        _selectedPassageRef = recognizedRef;
        _isConfirmingPassage = true;
      });
    } catch (e) {
      debugPrint('[RecitationMode] Error in recording processing: $e');
      setState(() {
        _isTranscribing = false;
        _isRecognizing = false;
      });
      _showError('Error: $e');
    }
  }

  void _showRecitationResults(PassageRangeRef passageRef, String transcribedText) {
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

      // Convert to ScriptureRef for results page (use start verse)
      final ref = ScriptureRef(
        bookId: passageRef.bookId,
        chapterNumber: passageRef.startChapter,
        verseNumber: passageRef.startVerse,
      );

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
                _isConfirmingPassage = false;
                _recognizedPassageRef = null;
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

  void _confirmPassage() {
    if (!_selectedPassageRef.complete) {
      _showError('Please select a valid passage');
      return;
    }

    debugPrint('[RecitationMode] User confirmed passage: ${_selectedPassageRef.display}');
    setState(() {
      _isConfirmingPassage = false;
    });
    _showRecitationResults(_selectedPassageRef, _transcribedText);
  }

  void _cancelConfirmation() {
    setState(() {
      _isConfirmingPassage = false;
      _recognizedPassageRef = null;
      _transcribedText = '';
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
            if (_isTranscribing || _isRecognizing)
              _buildLoadingSection()
            else if (_isConfirmingPassage)
              _buildConfirmationSection()
            else if (!_isPlayingBack) ...[
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

  Widget _buildLoadingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationSection() {
    final recognizedPassage = _recognizedPassageRef?.display ?? 'Could not recognize passage';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm Passage',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recognized:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                recognizedPassage,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Edit if needed:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        PassageRangeSelector(
          ref: _selectedPassageRef,
          onSelected: (ref) {
            setState(() => _selectedPassageRef = ref);
          },
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelConfirmation,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _confirmPassage,
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ],
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
                      label: const Text('Submit'),
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
