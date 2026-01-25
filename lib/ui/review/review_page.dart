import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/utils/date_utils.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/count_badge.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Page showing verses due for review, grouped by urgency.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Set<_Urgency> _collapsedSections = {};

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
            return const EmptyState(
              icon: Icons.check_circle_outline,
              message:
                  'No verses in your review queue yet.\nPractice some verses to get started!',
            );
          }

          final grouped = _groupByUrgency(verses);
          final dueCount = grouped.overdue.length + grouped.dueToday.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(dueCount: dueCount),
              const SizedBox(height: 16),
              if (grouped.overdue.isNotEmpty)
                _VerseSection(
                  title: 'Overdue',
                  verses: grouped.overdue,
                  bibleService: bibleService,
                  urgency: _Urgency.overdue,
                  isCollapsed: _collapsedSections.contains(_Urgency.overdue),
                  onToggle: () => _toggleSection(_Urgency.overdue),
                  onVerseTap: (ref) => showPracticeModeDialog(context, ref),
                ),
              if (grouped.dueToday.isNotEmpty)
                _VerseSection(
                  title: 'Due Today',
                  verses: grouped.dueToday,
                  bibleService: bibleService,
                  urgency: _Urgency.dueToday,
                  isCollapsed: _collapsedSections.contains(_Urgency.dueToday),
                  onToggle: () => _toggleSection(_Urgency.dueToday),
                  onVerseTap: (ref) => showPracticeModeDialog(context, ref),
                ),
              if (grouped.comingUp.isNotEmpty)
                _VerseSection(
                  title: 'Coming Up',
                  verses: grouped.comingUp,
                  bibleService: bibleService,
                  urgency: _Urgency.comingUp,
                  isCollapsed: _collapsedSections.contains(_Urgency.comingUp),
                  onToggle: () => _toggleSection(_Urgency.comingUp),
                  onVerseTap: (ref) => showPracticeModeDialog(context, ref),
                ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSection(_Urgency urgency) {
    setState(() {
      if (_collapsedSections.contains(urgency)) {
        _collapsedSections.remove(urgency);
      } else {
        _collapsedSections.add(urgency);
      }
    });
  }

  _GroupedVerses _groupByUrgency(List<VerseReviewState> verses) {
    final now = DateTime.now();
    final today = now.dateOnly;
    final tomorrow = today.add(const Duration(days: 1));

    final overdue = <VerseReviewState>[];
    final dueToday = <VerseReviewState>[];
    final comingUp = <VerseReviewState>[];

    for (final verse in verses) {
      final dueDate = verse.nextReviewDate.dateOnly;

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

extension on _Urgency {
  ThemeCardStyle get cardStyle => switch (this) {
    _Urgency.overdue => ThemeCardStyle.red,
    _Urgency.dueToday => ThemeCardStyle.brown,
    _Urgency.comingUp => ThemeCardStyle.neutral,
  };
}

class _SummaryCard extends StatelessWidget {
  final int dueCount;

  const _SummaryCard({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ThemeCard(
      style: ThemeCardStyle.neutral,
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
    );
  }
}

class _VerseSection extends StatelessWidget {
  final String title;
  final List<VerseReviewState> verses;
  final BibleService bibleService;
  final _Urgency urgency;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final void Function(ScriptureRef) onVerseTap;

  const _VerseSection({
    required this.title,
    required this.verses,
    required this.bibleService,
    required this.urgency,
    required this.isCollapsed,
    required this.onToggle,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ThemeCard(
        style: urgency.cardStyle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              child: Row(
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  CountBadge(count: verses.length),
                  const Spacer(),
                  Icon(
                    isCollapsed ? Icons.expand_more : Icons.expand_less,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 8),
              ...verses.map(
                (verse) => _VerseItem(
                  verse: verse,
                  bibleService: bibleService,
                  urgency: urgency,
                  onTap: () => onVerseTap(verse.ref),
                ),
              ),
            ],
          ],
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bibleService.getRefName(verse.ref),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  _formatDueDate(verse.nextReviewDate),
                  style: theme.textTheme.bodySmall?.copyWith(color: dueColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = now.dateOnly;
    final dueDay = date.dateOnly;
    final difference = dueDay.difference(today).inDays;

    if (difference < -1) return '${-difference} days ago';
    if (difference == -1) return 'yesterday';
    if (difference == 0) return 'today';
    if (difference == 1) return 'tomorrow';
    return 'in $difference days';
  }
}

