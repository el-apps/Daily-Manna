import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecitationResults extends StatefulWidget {
  final ScriptureRef ref;
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
    final actualVerse = bibleService.hasVerse(widget.ref)
        ? bibleService.getVerse(
            widget.ref.bookId!,
            widget.ref.chapterNumber!,
            widget.ref.verseNumber!,
          )
        : '';

    final scorePercentage = (widget.score * 100).toStringAsFixed(1);
    final isCorrect = widget.score >= 0.6;

    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Passage reference
            Text(
              '${widget.ref.bookId} ${widget.ref.chapterNumber}:${widget.ref.verseNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Score indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isCorrect ? Colors.green : Colors.red)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.close_circle,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCorrect ? 'Correct!' : 'Try Again',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isCorrect ? Colors.green : Colors.red,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Accuracy: $scorePercentage%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actual verse
            Text(
              'Original Verse:',
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
                actualVerse,
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

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onReciteAgain,
                    child: const Text('Recite Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
