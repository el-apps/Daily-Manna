import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/share_dialog.dart';
import 'package:word_tools/word_tools.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:daily_manna/ui/recitation/results/diff_legend.dart';
import 'package:daily_manna/ui/recitation/results/diff_colors.dart' as _;
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
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recitation Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  // Passage reference
                  Text(
                    bibleService.getRangeRefName(widget.ref),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  // Comparison with diff highlighting
                  DiffComparison(diff: _diff),
                ],
              ),
            ),
          ),
          // Fixed footer with progress bar and button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  LinearProgressIndicator(value: widget.score.clamp(0.0, 1.0)),
                  FilledButton(
                    onPressed: widget.onReciteAgain,
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareResult(BuildContext context) =>
      showDialog(context: context, builder: (_) => const ShareDialog());
}

class DiffComparison extends StatefulWidget {
  final List<DiffWord> diff;

  const DiffComparison({super.key, required this.diff});

  @override
  State<DiffComparison> createState() => _DiffComparisonState();
}

class _DiffComparisonState extends State<DiffComparison> {
  final Set<DiffStatus> _visibleStatuses = {
    DiffStatus.correct,
    DiffStatus.missing,
    DiffStatus.extra,
  };

  void _toggleVisibility(DiffStatus status) {
    setState(() {
      if (_visibleStatuses.contains(status)) {
        _visibleStatuses.remove(status);
      } else {
        _visibleStatuses.add(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredDiff = widget.diff
        .where((word) => _visibleStatuses.contains(word.status))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        MinimalLegend(
          visibleStatuses: _visibleStatuses,
          onToggle: _toggleVisibility,
        ),
        DiffPassageSection(diff: filteredDiff),
      ],
    );
  }
}

class DiffPassageSection extends StatelessWidget {
  final List<DiffWord> diff;

  const DiffPassageSection({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    final groups = _groupConsecutiveByStatus(diff);
    final baseStyle = Theme.of(context).textTheme.bodyLarge;

    return ThemeCard(
      child: RichText(
        text: TextSpan(
          children: [for (final group in groups) _buildSpan(group, baseStyle)],
        ),
      ),
    );
  }

  TextSpan _buildSpan(_WordGroup group, TextStyle? baseStyle) {
    final (bgColor, textColor) = group.status.colors;
    final text = group.words.map((w) => w.text).join(' ');
    final label = group.words[0].displayLabel;

    return TextSpan(
      text: '$label $text ',
      style: (baseStyle ?? const TextStyle()).copyWith(
        color: textColor,
        backgroundColor: bgColor,
      ),
    );
  }

  List<_WordGroup> _groupConsecutiveByStatus(List<DiffWord> words) {
    if (words.isEmpty) return [];

    final groups = <_WordGroup>[];
    var currentGroup = _WordGroup(status: words[0].status, words: [words[0]]);

    for (int i = 1; i < words.length; i++) {
      if (words[i].status == currentGroup.status) {
        currentGroup.words.add(words[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = _WordGroup(status: words[i].status, words: [words[i]]);
      }
    }
    groups.add(currentGroup);

    return groups;
  }
}

class _WordGroup {
  final DiffStatus status;
  final List<DiffWord> words;

  _WordGroup({required this.status, required this.words});
}
