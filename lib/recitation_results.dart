import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/scripture_range_ref.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecitationResults extends StatefulWidget {
  final ScriptureRangeRef ref;
  final String transcribedText;
  final double score;
  final VoidCallback onReciteAgain;

  const RecitationResults({
    super.key,
    required this.ref,
    required this.transcribedText,
    required this.score,
    required this.onReciteAgain,
  });

  @override
  State<RecitationResults> createState() => _RecitationResultsState();
}

class _RecitationResultsState extends State<RecitationResults> {
  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final actualPassage = bibleService.getPassageRange(
      widget.ref.bookId,
      widget.ref.startChapter,
      widget.ref.startVerse,
      endChapter: widget.ref.endChapter,
      endVerse: widget.ref.endVerse,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Passage reference
            Text(
              bibleService.getRangeRefName(widget.ref),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Actual passage
            Text(
              'Original Passage:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actualPassage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),

            // Transcribed text
            Text(
              'Your Recitation:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.transcribedText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 32),

            // Progress bar
            LinearProgressIndicator(value: widget.score),
            const SizedBox(height: 24),

            // Action button
            FilledButton(
              onPressed: widget.onReciteAgain,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
