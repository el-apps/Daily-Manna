import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/scripture_range_ref.dart';
import 'package:daily_manna/word_diff.dart';
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
  late final String _actualPassage;
  late final WordDiff _diff;

  @override
  void initState() {
    super.initState();
    final bibleService = context.read<BibleService>();
    _actualPassage = bibleService.getPassageRange(
      widget.ref.bookId,
      widget.ref.startChapter,
      widget.ref.startVerse,
      endChapter: widget.ref.endChapter,
      endVerse: widget.ref.endVerse,
    );
    _diff = computeWordDiff(_actualPassage, widget.transcribedText);
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

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

            // Comparison with diff highlighting
            DiffComparison(diff: _diff),
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

class DiffComparison extends StatelessWidget {
  final WordDiff diff;

  const DiffComparison({
    super.key,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiffLegend(),
        const SizedBox(height: 24),
        DiffPassageSection(
          label: 'Original Passage:',
          words: diff.original,
        ),
        const SizedBox(height: 24),
        DiffPassageSection(
          label: 'Your Recitation:',
          words: diff.transcribed,
        ),
      ],
    );
  }
}

class DiffLegend extends StatelessWidget {
  const DiffLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              LegendItem(label: '✓', text: 'Correct', color: Colors.green),
              LegendItem(label: '−', text: 'Missing', color: Colors.red),
              LegendItem(label: '+', text: 'Extra', color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const LegendItem({
    super.key,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class DiffPassageSection extends StatelessWidget {
  final String label;
  final List<DiffWord> words;

  const DiffPassageSection({
    super.key,
    required this.label,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final word in words) DiffWordWidget(word: word),
            ],
          ),
        ),
      ],
    );
  }
}

class DiffWordWidget extends StatelessWidget {
  final DiffWord word;

  const DiffWordWidget({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, textColor) = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            word.displayLabel,
            style: TextStyle(
              color: borderColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            word.text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  (Color bgColor, Color borderColor, Color textColor) _getColors() {
    switch (word.status) {
      case DiffStatus.correct:
        return (
          Colors.green.withValues(alpha: 0.15),
          Colors.green,
          Colors.green.shade900,
        );
      case DiffStatus.missing:
        return (
          Colors.red.withValues(alpha: 0.15),
          Colors.red,
          Colors.red.shade900,
        );
      case DiffStatus.extra:
        return (
          Colors.orange.withValues(alpha: 0.15),
          Colors.orange,
          Colors.orange.shade900,
        );
      case DiffStatus.substituted:
        return (
          Colors.yellow.withValues(alpha: 0.15),
          Colors.yellow.shade700,
          Colors.yellow.shade900,
        );
    }
  }
}
