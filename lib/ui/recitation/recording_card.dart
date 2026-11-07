import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';

enum RecordingState { idle, recording, muted }

class RecordingCard extends StatelessWidget {
  final RecordingState state;
  final VoidCallback onToggle;
  final VoidCallback onToggleMute;
  final bool isBusy;
  final bool canStart;
  final Widget? inputSelector;

  const RecordingCard({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onToggleMute,
    this.isBusy = false,
    this.canStart = true,
    this.inputSelector,
  });

  @override
  Widget build(BuildContext context) {
    final isRecording = state != RecordingState.idle;
    final isMuted = state == RecordingState.muted;

    return ThemeCard(
      child: Column(
        children: [
          Icon(
            isMuted
                ? Icons.mic_off
                : isRecording
                ? Icons.mic
                : Icons.mic_none,
            size: 80,
            color: isRecording && !isMuted ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            isMuted
                ? 'Recording paused'
                : isRecording
                ? 'Recording...'
                : 'Ready to recite',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (isMuted) ...[
            const SizedBox(height: 8),
            const Text('Unmute to continue your recitation.'),
          ],
          if (inputSelector != null) ...[
            const SizedBox(height: 24),
            inputSelector!,
          ],
          const SizedBox(height: 48),
          if (isRecording) ...[
            OutlinedButton.icon(
              onPressed: isBusy ? null : onToggleMute,
              icon: Icon(isMuted ? Icons.mic : Icons.mic_off),
              label: Text(isMuted ? 'Unmute' : 'Mute'),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: isBusy || (!isRecording && !canStart) ? null : onToggle,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
          ),
        ],
      ),
    );
  }
}
