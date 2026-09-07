import 'package:intl/intl.dart';

import 'package:daily_manna/utils/date_utils.dart';

import 'package:daily_manna/ui/empty_state.dart';

import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/utils/scripture_range_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab showing verses sorted by next review date.
class ReviewTab extends StatelessWidget {
  static final _dateFormat = DateFormat.yMMMd();
  final void Function(ScriptureRangeRef) onPassageSelected;

  const ReviewTab({super.key, required this.onPassageSelected});

  @override
  Widget build(BuildContext context) {
    final srService = context.read<SpacedRepetitionService>();
    final bibleService = context.read<BibleService>();

    return FutureBuilder<List<VerseReviewState>>(
      future: srService.getVersesByReviewDate(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suggestions = _mergeByDueDay(snapshot.data ?? []);

        if (suggestions.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            message:
                'No verses due for review!\nInteract with some verses to build your queue.',
          );
        }

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              title: Text(bibleService.getRangeRefName(suggestion.ref)),
              subtitle: Text(_formatReviewDate(suggestion.nextReviewDate)),
              onTap: () => onPassageSelected(suggestion.ref),
            );
          },
        );
      },
    );
  }

  List<_ReviewSuggestion> _mergeByDueDay(List<VerseReviewState> verses) {
    final groups = <DateTime, List<VerseReviewState>>{};
    for (final verse in verses) {
      final dueDay = verse.nextReviewDate.dateOnly;
      groups.putIfAbsent(dueDay, () => []).add(verse);
    }

    return [for (final group in groups.values) ..._mergeGroup(group)];
  }

  List<_ReviewSuggestion> _mergeGroup(List<VerseReviewState> group) {
    final mergedRefs = mergeAdjoiningRanges(
      group.map((verse) => _toRange(verse.ref)).toList(),
    );
    return [
      for (final ref in mergedRefs)
        _ReviewSuggestion(ref, group.first.nextReviewDate),
    ];
  }

  ScriptureRangeRef _toRange(ScriptureRef ref) => ScriptureRangeRef(
    bookId: ref.bookId!,
    chapter: ref.chapterNumber!,
    startVerse: ref.verseNumber!,
  );
}

class _ReviewSuggestion {
  final ScriptureRangeRef ref;
  final DateTime nextReviewDate;

  const _ReviewSuggestion(this.ref, this.nextReviewDate);
}

String _formatReviewDate(DateTime date) {
  final now = DateTime.now();
  final today = now.dateOnly;
  final reviewDay = date.dateOnly;
  final difference = reviewDay.difference(today).inDays;

  if (difference < 0) {
    return 'Due ${-difference} day${difference == -1 ? '' : 's'} ago';
  }
  if (difference == 0) return 'Due today';
  if (difference == 1) return 'Due tomorrow';
  return 'Due ${ReviewTab._dateFormat.format(date)}';
}
