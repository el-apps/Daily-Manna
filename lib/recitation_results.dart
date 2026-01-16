import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/scripture_range_ref.dart';
import 'package:word_tools/word_tools.dart';
import 'package:daily_manna/ui/theme_card.dart';
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
      appBar: AppBar(title: const Text('Recitation Results')),
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
                  LinearProgressIndicator(value: widget.score),
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

}

class DiffComparison extends StatefulWidget {
  final List<DiffWord> diff;

  const DiffComparison({
    super.key,
    required this.diff,
  });

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

class MinimalLegend extends StatelessWidget {
  final Set<DiffStatus> visibleStatuses;
  final Function(DiffStatus) onToggle;

  const MinimalLegend({
    super.key,
    required this.visibleStatuses,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          _LegendColor(
            color: Colors.green,
            label: 'Correct',
            isVisible: visibleStatuses.contains(DiffStatus.correct),
            onTap: () => onToggle(DiffStatus.correct),
          ),
          _LegendColor(
            color: Colors.red,
            label: 'Missing',
            isVisible: visibleStatuses.contains(DiffStatus.missing),
            onTap: () => onToggle(DiffStatus.missing),
          ),
          _LegendColor(
            color: Colors.orange,
            label: 'Extra',
            isVisible: visibleStatuses.contains(DiffStatus.extra),
            onTap: () => onToggle(DiffStatus.extra),
          ),
        ],
      ),
    );
  }
}

class _LegendColor extends StatelessWidget {
  final Color color;
  final String label;
  final bool isVisible;
  final VoidCallback onTap;

  const _LegendColor({
    required this.color,
    required this.label,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Opacity(
          opacity: isVisible ? 1.0 : 0.4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isVisible
                      ? color.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  border: Border.all(
                    color: isVisible ? color : Colors.grey,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
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
    final groups = _groupConsecutiveByStatus(diff);
    final baseStyle = Theme.of(context).textTheme.bodyLarge;

    return ThemeCard(
      child: RichText(
        text: TextSpan(
          children: [
            for (final group in groups) _buildSpan(group, baseStyle),
          ],
        ),
      ),
    );
  }

  TextSpan _buildSpan(_WordGroup group, TextStyle? baseStyle) {
    final (bgColor, borderColor, textColor) = _getColors(group.status);
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

  (Color bgColor, Color borderColor, Color textColor) _getColors(DiffStatus status) {
    switch (status) {
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

  List<_WordGroup> _groupConsecutiveByStatus(List<DiffWord> words) {
    if (words.isEmpty) return [];

    final groups = <_WordGroup>[];
    var currentGroup = _WordGroup(
      status: words[0].status,
      words: [words[0]],
    );

    for (int i = 1; i < words.length; i++) {
      if (words[i].status == currentGroup.status) {
        currentGroup.words.add(words[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = _WordGroup(
          status: words[i].status,
          words: [words[i]],
        );
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
