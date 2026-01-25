import 'package:intl/intl.dart';

import 'package:daily_manna/ui/empty_state.dart';

import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab showing verses sorted by next review date.
class ReviewTab extends StatelessWidget {
  static final _dateFormat = DateFormat.yMMMd();
  final void Function(ScriptureRef) onVerseSelected;

  const ReviewTab({super.key, required this.onVerseSelected});

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

        final verses = snapshot.data ?? [];

        if (verses.isEmpty) {
          return const EmptyState(
          icon: Icons.check_circle_outline,
          message: 'No verses due for review!\nPractice some verses to build your queue.',
        );
        }

        return ListView.builder(
          itemCount: verses.length,
          itemBuilder: (context, index) {
            final state = verses[index];
            return ListTile(
              title: Text(bibleService.getRefName(state.ref)),
              subtitle: Text(_formatReviewDate(state.nextReviewDate)),
              onTap: () => onVerseSelected(state.ref),
            );
          },
        );
      },
    );
  }
}

String _formatReviewDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final reviewDay = DateTime(date.year, date.month, date.day);
  final difference = reviewDay.difference(today).inDays;

  if (difference < 0) {
    return 'Due ${-difference} day${difference == -1 ? '' : 's'} ago';
  }
  if (difference == 0) return 'Due today';
  if (difference == 1) return 'Due tomorrow';
  return 'Due ${ReviewTab._dateFormat.format(date)}';
}
