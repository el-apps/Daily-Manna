import 'package:intl/intl.dart';

import 'package:daily_manna/utils/date_utils.dart';

import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab showing recently practiced verses.
class RecentsTab extends StatelessWidget {
  static final _dateFormat = DateFormat.yMMMd();
  final void Function(ScriptureRef) onVerseSelected;

  const RecentsTab({super.key, required this.onVerseSelected});

  @override
  Widget build(BuildContext context) {
    final srService = context.read<SpacedRepetitionService>();
    final bibleService = context.read<BibleService>();

    return FutureBuilder<List<VerseReviewState>>(
      future: srService.getRecentVerses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final recentVerses = snapshot.data ?? [];

        if (recentVerses.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            message:
                'No practice history yet.\nComplete a memorization to get started!',
          );
        }

        return ListView.builder(
          itemCount: recentVerses.length,
          itemBuilder: (context, index) {
            final state = recentVerses[index];
            return ListTile(
              title: Text(bibleService.getRefName(state.ref)),
              subtitle: Text(_formatLastPracticed(state.lastReview)),
              onTap: () => onVerseSelected(state.ref),
            );
          },
        );
      },
    );
  }
}

String _formatLastPracticed(DateTime date) {
  final now = DateTime.now();
  final today = now.dateOnly;
  final practiceDay = date.dateOnly;
  final difference = today.difference(practiceDay).inDays;

  if (difference == 0) return 'Practiced today';
  if (difference == 1) return 'Practiced yesterday';
  if (difference < 7) return 'Practiced $difference days ago';
  return 'Practiced ${RecentsTab._dateFormat.format(date)}';
}

