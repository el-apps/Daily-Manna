import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Page showing verses due for review, grouped by urgency.
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final srService = context.read<SpacedRepetitionService>();
    final bibleService = context.read<BibleService>();

    return AppScaffold(
      title: 'Review',
      showShareButton: false,
      body: FutureBuilder<List<VerseReviewState>>(
        future: srService.getVersesByReviewDate(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final verses = snapshot.data ?? [];
          if (verses.isEmpty) {
            return _EmptyState();
          }

          final grouped = _groupByUrgency(verses);
          final dueCount = grouped.overdue.length + grouped.dueToday.length;

          return ListView(
            children: [
              _SummaryCard(dueCount: dueCount),
              if (grouped.overdue.isNotEmpty)
                _VerseSection(
                  title: 'Overdue',
                  verses: grouped.overdue,
                  bibleService: bibleService,
                  urgency: _Urgency.overdue,
                  onVerseTap: (ref) => _showPracticeDialog(context, ref),
                ),
              if (grouped.dueToday.isNotEmpty)
                _VerseSection(
                  title: 'Due Today',
                  verses: grouped.dueToday,
                  bibleService: bibleService,
                  urgency: _Urgency.dueToday,
                  onVerseTap: (ref) => _showPracticeDialog(context, ref),
                ),
              if (grouped.comingUp.isNotEmpty)
                _VerseSection(
                  title: 'Coming Up',
                  verses: grouped.comingUp,
                  bibleService: bibleService,
                  urgency: _Urgency.comingUp,
                  onVerseTap: (ref) => _showPracticeDialog(context, ref),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showPracticeDialog(BuildContext context, ScriptureRef ref) {
    final bibleService = context.read<BibleService>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bibleService.getRefName(ref)),
        content: const Text('How would you like to practice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecitationMode()),
              );
            },
            child: const Text('🎤 Recite'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VerseMemorization(initialRef: ref),
                ),
              );
            },
            child: const Text('⌨️ Memorize'),
          ),
        ],
      ),
    );
  }

  _GroupedVerses _groupByUrgency(List<VerseReviewState> verses) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final overdue = <VerseReviewState>[];
    final dueToday = <VerseReviewState>[];
    final comingUp = <VerseReviewState>[];

    for (final verse in verses) {
      final dueDate = DateTime(
        verse.nextReviewDate.year,
        verse.nextReviewDate.month,
        verse.nextReviewDate.day,
      );

      if (dueDate.isBefore(today)) {
        overdue.add(verse);
      } else if (dueDate.isBefore(tomorrow)) {
        dueToday.add(verse);
      } else {
        comingUp.add(verse);
      }
    }

    return _GroupedVerses(
      overdue: overdue,
      dueToday: dueToday,
      comingUp: comingUp,
    );
  }
}

class _GroupedVerses {
  final List<VerseReviewState> overdue;
  final List<VerseReviewState> dueToday;
  final List<VerseReviewState> comingUp;

  _GroupedVerses({
    required this.overdue,
    required this.dueToday,
    required this.comingUp,
  });
}

enum _Urgency { overdue, dueToday, comingUp }

class _SummaryCard extends StatelessWidget {
  final int dueCount;

  const _SummaryCard({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$dueCount',
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              dueCount == 1 ? 'verse due for review' : 'verses due for review',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseSection extends StatelessWidget {
  final String title;
  final List<VerseReviewState> verses;
  final BibleService bibleService;
  final _Urgency urgency;
  final void Function(ScriptureRef) onVerseTap;

  const _VerseSection({
    required this.title,
    required this.verses,
    required this.bibleService,
    required this.urgency,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${verses.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...verses.map(
          (verse) => _VerseItem(
            verse: verse,
            bibleService: bibleService,
            urgency: urgency,
            onTap: () => onVerseTap(verse.ref),
          ),
        ),
      ],
    );
  }
}

class _VerseItem extends StatelessWidget {
  final VerseReviewState verse;
  final BibleService bibleService;
  final _Urgency urgency;
  final VoidCallback onTap;

  const _VerseItem({
    required this.verse,
    required this.bibleService,
    required this.urgency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueColor = switch (urgency) {
      _Urgency.overdue => theme.colorScheme.error,
      _Urgency.dueToday => Colors.orange,
      _Urgency.comingUp => theme.colorScheme.onSurfaceVariant,
    };

    return ListTile(
      title: Text(bibleService.getRefName(verse.ref)),
      subtitle: Text(
        _formatDueDate(verse.nextReviewDate),
        style: TextStyle(color: dueColor),
      ),
      onTap: onTap,
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(date.year, date.month, date.day);
    final difference = dueDay.difference(today).inDays;

    if (difference < -1) return '${-difference} days ago';
    if (difference == -1) return 'yesterday';
    if (difference == 0) return 'today';
    if (difference == 1) return 'tomorrow';
    return 'in $difference days';
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
            'No verses in your review queue yet.\nPractice some verses to get started!',
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
