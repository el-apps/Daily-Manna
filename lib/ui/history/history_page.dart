import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/ui/history/history_activity_grid.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/history/result_card.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:daily_manna/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

List<db.Result> filterResultsForDate(
  List<db.Result> results,
  DateTime selectedDate,
) {
  final selectedDay = selectedDate.dateOnly;
  return results
      .where((result) => result.timestamp.localDateOnly == selectedDay)
      .toList();
}

List<db.Result> filterResultsByType(
  List<db.Result> results,
  db.ResultType? type,
) {
  if (type == null) return results;
  return results.where((result) => result.type == type).toList();
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  db.ResultType? _filterType;
  DateTime _selectedDate = DateTime.now().dateOnly;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                final filtered = filterResultsByType(results, _filterType);
                final selectedResults = filterResultsForDate(
                  filtered,
                  _selectedDate,
                );

                if (results.isEmpty) {
                  return EmptyState(
                    icon: Icons.history,
                    message:
                        'No practice history yet.\nComplete a memorization or recitation to get started!',
                  );
                }

                final activityDays = normalizeActivityDays(
                  filtered.map((result) => result.timestamp),
                );

                return ListView(
                  key: const PageStorageKey('history-results-list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    HistoryActivityGrid(
                      activityDays: activityDays,
                      selectedDate: _selectedDate,
                      onDateSelected: (date) =>
                          setState(() => _selectedDate = date.dateOnly),
                    ),
                    const SizedBox(height: 16),
                    if (selectedResults.isEmpty)
                      EmptyState(
                        icon: Icons.history,
                        message: _filterType != null
                            ? 'No results on ${DateFormat.yMMMMd().format(_selectedDate)} match the filter.'
                            : 'No results on ${DateFormat.yMMMMd().format(_selectedDate)}.',
                      )
                    else
                      _DateGroup(
                        label: DateFormat.yMMMMd().format(_selectedDate),
                        results: selectedResults,
                        bibleService: bibleService,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  static const _filterOptions = [
    (label: 'Study', type: db.ResultType.study),
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
            onSelected: (_) =>
                onSelected(selectedType == option.type ? null : option.type),
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
      ...results.map((result) {
        final card = ResultCard(
          result: result,
          reference: _getReference(result),
          score: ScoreData(value: result.score, attempts: result.attempts ?? 1),
          onPractice: () => _showPracticeDialog(context, result),
        );

        if (result.type == db.ResultType.study) {
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudyNotesDetailPage(result: result),
              ),
            ),
            child: card,
          );
        }
        return card;
      }),
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
