import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tab showing verses due for review based on spaced repetition.
class ReviewTab extends StatelessWidget {
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
          return _EmptyState();
        }

        return ListView.builder(
          itemCount: verses.length,
          itemBuilder: (context, index) {
            final state = verses[index];
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
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No verses due for review!\nPractice some verses to build your queue.',
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
