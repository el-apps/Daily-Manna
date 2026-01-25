import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/utils/date_utils.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/history/result_card.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  db.ResultType? _filterType;

  @override
  Widget build(BuildContext context) {
    final resultsService = context.read<ResultsService>();
    final bibleService = context.read<BibleService>();

    return AppScaffold(
      title: 'History',
      body: Column(
        children: [
          _FilterChips(
            selectedType: _filterType,
            onSelected: (type) => setState(() => _filterType = type),
          ),
          Expanded(
            child: StreamBuilder<List<db.Result>>(
              stream: resultsService.watchAllResults(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final results = snapshot.data ?? [];
                final filtered = _filterType == null
                    ? results
                    : results.where((r) => r.type == _filterType).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.history,
                    message: _filterType != null
                        ? 'No results match the filter.'
                        : 'No practice history yet.\nComplete a memorization or recitation to get started!',
                  );
                }

                final grouped = _groupByDate(filtered);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final group = grouped[index];
                    return _DateGroup(
                      label: group.label,
                      results: group.results,
                      bibleService: bibleService,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_ResultGroup> _groupByDate(List<db.Result> results) {
    final now = DateTime.now();
    final today = now.dateOnly;
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<db.Result>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final result in results) {
      final date = result.timestamp.dateOnly;

      if (date == today) {
        groups['Today']!.add(result);
      } else if (date == yesterday) {
        groups['Yesterday']!.add(result);
      } else if (date.isAfter(weekAgo)) {
        groups['This Week']!.add(result);
      } else {
        groups['Earlier']!.add(result);
      }
    }

    return groups.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => _ResultGroup(label: e.key, results: e.value))
        .toList();
  }
}

class _ResultGroup {
  final String label;
  final List<db.Result> results;

  _ResultGroup({required this.label, required this.results});
}

class _FilterChips extends StatelessWidget {
  static const _filterOptions = [
    (label: 'Recitation', type: db.ResultType.recitation),
    (label: 'Memorization', type: db.ResultType.memorization),
  ];

  final db.ResultType? selectedType;
  final ValueChanged<db.ResultType?> onSelected;

  const _FilterChips({required this.selectedType, required this.onSelected});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: selectedType == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final option in _filterOptions)
          FilterChip(
            label: Text(option.label),
            selected: selectedType == option.type,
            onSelected: (_) => onSelected(
              selectedType == option.type ? null : option.type,
            ),
          ),
      ],
    ),
  );
}

class _DateGroup extends StatelessWidget {
  final String label;
  final List<db.Result> results;
  final BibleService bibleService;

  const _DateGroup({
    required this.label,
    required this.results,
    required this.bibleService,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      ...results.map(
        (result) => ResultCard(
          result: result,
          reference: _getReference(result),
          score: ScoreData(value: result.score, attempts: result.attempts ?? 1),
          onPractice: () => _showPracticeDialog(context, result),
        ),
      ),
    ],
  );

  void _showPracticeDialog(BuildContext context, db.Result result) {
    showPracticeModeDialog(
      context,
      ScriptureRef(
        bookId: result.bookId,
        chapterNumber: result.startChapter,
        verseNumber: result.startVerse,
      ),
    );
  }

  String _getReference(db.Result result) {
    final bookTitle = bibleService.booksMap[result.bookId]?.title ?? 'Unknown';
    final start = '${result.startChapter}:${result.startVerse}';

    if (result.endVerse != null && result.endVerse != result.startVerse) {
      if (result.endChapter != null &&
          result.endChapter != result.startChapter) {
        return '$bookTitle $start-${result.endChapter}:${result.endVerse}';
      }
      return '$bookTitle $start-${result.endVerse}';
    }
    return '$bookTitle $start';
  }
}

