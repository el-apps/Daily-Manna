import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/history/result_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  ResultType? _filterType;

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
            child: StreamBuilder<List<Result>>(
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
                  return _EmptyState(hasFilter: _filterType != null);
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

  List<_ResultGroup> _groupByDate(List<Result> results) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<Result>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Earlier': [],
    };

    for (final result in results) {
      final date = DateTime(
        result.timestamp.year,
        result.timestamp.month,
        result.timestamp.day,
      );

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
  final List<Result> results;

  _ResultGroup({required this.label, required this.results});
}

class _FilterChips extends StatelessWidget {
  final ResultType? selectedType;
  final ValueChanged<ResultType?> onSelected;

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
            FilterChip(
              label: const Text('Recitation'),
              selected: selectedType == ResultType.recitation,
              onSelected: (_) => onSelected(
                selectedType == ResultType.recitation
                    ? null
                    : ResultType.recitation,
              ),
            ),
            FilterChip(
              label: const Text('Memorization'),
              selected: selectedType == ResultType.memorization,
              onSelected: (_) => onSelected(
                selectedType == ResultType.memorization
                    ? null
                    : ResultType.memorization,
              ),
            ),
          ],
        ),
      );
}

class _DateGroup extends StatelessWidget {
  final String label;
  final List<Result> results;
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
              starDisplay: _getStarDisplay(result),
            ),
          ),
        ],
      );

  String _getReference(Result result) {
    final bookTitle = bibleService.booksMap[result.bookId]?.title ?? 'Unknown';

    if (result.endChapter != null && result.endVerse != null) {
      if (result.endChapter == result.startChapter) {
        return '$bookTitle ${result.startChapter}:${result.startVerse}-${result.endVerse}';
      }
      return '$bookTitle ${result.startChapter}:${result.startVerse}-${result.endChapter}:${result.endVerse}';
    }
    return '$bookTitle ${result.startChapter}:${result.startVerse}';
  }

  String _getStarDisplay(Result result) {
    final stars = scoreToStars(result.score);
    return '⭐' * stars + '☆' * (5 - stars);
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

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
                hasFilter
                    ? 'No results match the filter.'
                    : 'No practice history yet.\nComplete a memorization or recitation to get started!',
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
