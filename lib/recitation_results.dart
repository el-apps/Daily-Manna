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
  final List<DiffWord> diff;

  const DiffComparison({
    super.key,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MinimalLegend(),
        const SizedBox(height: 16),
        DiffPassageSection(diff: diff),
      ],
    );
  }
}

class MinimalLegend extends StatelessWidget {
  const MinimalLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendColor(color: Colors.green, label: 'Correct'),
        _LegendColor(color: Colors.red, label: 'Missing'),
        _LegendColor(color: Colors.orange, label: 'Extra'),
      ],
    );
  }
}

class _LegendColor extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendColor({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class DiffPassageSection extends StatelessWidget {
  final List<DiffWord> diff;

  const DiffPassageSection({
    super.key,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              for (final word in diff)
                DiffWordWidget(word: word),
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
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            word.displayLabel,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            word.text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
          Colors.green.withValues(alpha: 0.25),
          Colors.green.shade700,
          Colors.green.shade100,
        );
      case DiffStatus.missing:
        return (
          Colors.red.withValues(alpha: 0.25),
          Colors.red.shade700,
          Colors.red.shade100,
        );
      case DiffStatus.extra:
        return (
          Colors.orange.withValues(alpha: 0.25),
          Colors.orange.shade700,
          Colors.orange.shade100,
        );
    }
  }
}
