import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:word_tools/word_tools.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:daily_manna/ui/recitation/results/star_utils.dart';
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
  late final List<DiffWord> _diff;

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
  Widget build(BuildContext context) => _DiffViewWrapper(
        ref: widget.ref,
        diff: _diff,
        score: widget.score,
        onReciteAgain: widget.onReciteAgain,
      );
}

class _DiffViewWrapper extends StatefulWidget {
  final ScriptureRangeRef ref;
  final List<DiffWord> diff;
  final double score;
  final VoidCallback onReciteAgain;

  const _DiffViewWrapper({
    required this.ref,
    required this.diff,
    required this.score,
    required this.onReciteAgain,
  });

  @override
  State<_DiffViewWrapper> createState() => _DiffViewWrapperState();
}

class _DiffViewWrapperState extends State<_DiffViewWrapper> {
  bool _showExpected = true;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final filteredDiff = _filterDiff(widget.diff, _showExpected);

    return AppScaffold(
      title: 'Recitation Results',
      body: Column(
        children: [
          // Fixed header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 12,
              children: [
                // Passage reference
                Text(
                  bibleService.getRangeRefName(widget.ref),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                // Star rating
                StarUtils.buildStarDisplay(widget.score),
                // View toggle buttons
                SegmentedButton<bool>(
                  selected: {_showExpected},
                  onSelectionChanged: (selected) {
                    setState(() => _showExpected = selected.first);
                  },
                  segments: const [
                    ButtonSegment(label: Text('Expected'), value: true),
                    ButtonSegment(label: Text('Spoken'), value: false),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DiffPassageSection(diff: filteredDiff),
            ),
          ),
          // Fixed footer with button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: widget.onReciteAgain,
                child: const Text('Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DiffWord> _filterDiff(List<DiffWord> diff, bool showExpected) {
    if (showExpected) {
      // Expected: show correct + missing
      return diff
          .where((word) =>
              word.status == DiffStatus.correct ||
              word.status == DiffStatus.missing)
          .toList();
    } else {
      // Spoken: show correct + extra
      return diff
          .where((word) =>
              word.status == DiffStatus.correct ||
              word.status == DiffStatus.extra)
          .toList();
    }
  }
}
class DiffPassageSection extends StatelessWidget {
  final List<DiffWord> diff;

  const DiffPassageSection({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge;

    return ThemeCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RichText(
          text: TextSpan(
            children: [for (final word in diff) _buildWordSpan(word, baseStyle)],
          ),
        ),
      ),
    );
  }

  TextSpan _buildWordSpan(DiffWord word, TextStyle? baseStyle) {
    final baseTextStyle = baseStyle ?? const TextStyle();

    return switch (word.status) {
      DiffStatus.correct => TextSpan(
            text: '${word.text} ',
            style: baseTextStyle,
          ),
      DiffStatus.missing => TextSpan(
            text: '${word.text} ',
            style: baseTextStyle.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
      DiffStatus.extra => TextSpan(
            text: '${word.text} ',
            style: baseTextStyle.copyWith(
              color: Colors.red,
              decoration: TextDecoration.lineThrough,
            ),
          ),
    };
  }
}
