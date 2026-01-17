import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:daily_manna/ui/theme_card.dart';

class RecitationPlaybackSection extends StatelessWidget {
  const RecitationPlaybackSection({
    super.key,
    required this.audioPlayer,
    required this.onTogglePlayback,
    required this.onStopPlayback,
    required this.onDiscard,
    required this.onSubmit,
  });

  final AudioPlayer audioPlayer;
  final VoidCallback onTogglePlayback;
  final VoidCallback onStopPlayback;
  final VoidCallback onDiscard;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      spacing: 24,
      children: [
        Icon(Icons.music_note, size: 80, color: Colors.blue),
        StreamBuilder<PlayerState>(
          stream: audioPlayer.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final isPlaying = playerState?.playing ?? false;

            return Column(
              spacing: 24,
              children: [
                // Playback progress
                StreamBuilder<Duration?>(
                  stream: audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = audioPlayer.duration ?? Duration.zero;
                    final durationMs = duration.inMilliseconds.toDouble();
                    final positionMs = position.inMilliseconds.toDouble().clamp(
                      0.0,
                      durationMs,
                    );

                    return Column(
                      spacing: 8,
                      children: [
                        if (durationMs > 0)
                          SliderTheme(
                            data: SliderThemeData(trackHeight: 4),
                            child: Slider(
                              min: 0,
                              max: durationMs,
                              value: positionMs,
                              onChanged: (double value) {
                                audioPlayer.seek(
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
                // Play/Pause button
                FilledButton.icon(
                  onPressed: onTogglePlayback,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                ),
              ],
            );
          },
        ),
        // Action buttons
        Row(
          spacing: 16,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDiscard,
                icon: const Icon(Icons.delete),
                label: const Text('Discard'),
              ),
            ),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.check),
                label: const Text('Submit'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
