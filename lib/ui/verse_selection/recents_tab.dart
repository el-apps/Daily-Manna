import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab showing recently practiced verses.
class RecentsTab extends StatelessWidget {
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
          return _EmptyState();
        }

        return ListView.builder(
          itemCount: recentVerses.length,
          itemBuilder: (context, index) {
            final state = recentVerses[index];
            return ListTile(
              title: Text(bibleService.getRefName(state.ref)),
              onTap: () => onVerseSelected(state.ref),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No practice history yet.\nComplete a memorization to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
}
