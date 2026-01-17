import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';

enum RecordingState { idle, recording }

class RecordingCard extends StatelessWidget {
  final RecordingState state;
  final VoidCallback onToggle;

  const RecordingCard({super.key, required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isRecording = state == RecordingState.recording;

    return ThemeCard(
      child: Column(
        children: [
          Icon(
            isRecording ? Icons.mic : Icons.mic_none,
            size: 80,
            color: isRecording ? Colors.red : Colors.grey,
          ),
          const SizedBox(height: 24),
          Text(
            isRecording ? 'Recording...' : 'Ready to recite',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
          ),
        ],
      ),
    );
  }
}
