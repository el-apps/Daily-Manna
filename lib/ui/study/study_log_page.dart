import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/history/result_card.dart';
import 'package:daily_manna/ui/memorization/verse_selector.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Page for logging study sessions with passage and optional notes.
class StudyLogPage extends StatefulWidget {
  const StudyLogPage({super.key});

  @override
  State<StudyLogPage> createState() => _StudyLogPageState();
}

class _StudyLogPageState extends State<StudyLogPage> {
  ScriptureRangeRef? _selectedPassage;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return AppScaffold(
      title: 'Study Log',
      showShareButton: false,
      body: Column(
        children: [
          // Form section (fixed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassageSelector(
                  selectedPassage: _selectedPassage,
                  onSelected: (ref) => setState(() => _selectedPassage = ref),
                ),
                const SizedBox(height: 16),
                _NotesField(controller: _notesController),
                const SizedBox(height: 24),
                _SaveButton(
                  enabled: _selectedPassage?.complete ?? false,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // History section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Study',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          // History list (scrollable, takes remaining space)
          Expanded(
            child: _StudyHistoryList(db: db),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final passage = _selectedPassage!;
    final notes = _notesController.text;

    final result = ResultsCompanion.insert(
      type: ResultType.study,
      bookId: passage.bookId,
      startChapter: passage.chapter,
      startVerse: passage.startVerse,
      endVerse: Value(passage.endVerse),
      score: 1.0,
      timestamp: DateTime.now(),
      notes: notes.isNotEmpty ? Value(notes) : const Value.absent(),
      attempts: const Value.absent(),
      endChapter: const Value.absent(),
    );

    await context.read<AppDatabase>().insertResult(result);
    if (mounted) Navigator.pop(context);
  }
}

class _PassageSelector extends StatelessWidget {
  const _PassageSelector({
    required this.selectedPassage,
    required this.onSelected,
  });

  final ScriptureRangeRef? selectedPassage;
  final ValueChanged<ScriptureRangeRef> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: VerseSelector.range(
      rangeRef: selectedPassage ??
          const ScriptureRangeRef(bookId: '', chapter: 0, startVerse: 0),
      onRangeSelected: onSelected,
    ),
  );
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: const InputDecoration(
      hintText: 'Add notes (optional)',
      border: OutlineInputBorder(),
    ),
    maxLines: 3,
    minLines: 2,
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: enabled ? onPressed : null,
    child: const Text('Save'),
  );
}


class _StudyHistoryList extends StatelessWidget {
  const _StudyHistoryList({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    return StreamBuilder<List<Result>>(
      stream: db.watchStudyResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const EmptyState(
            icon: Icons.menu_book,
            message: 'No study sessions yet',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final result = results[index];
            final refName = bibleService.getRangeRefName(ScriptureRangeRef(
              bookId: result.bookId,
              chapter: result.startChapter,
              startVerse: result.startVerse,
              endVerse: result.endVerse,
            ));

            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudyNotesDetailPage(result: result),
                ),
              ),
              child: ResultCard(
                result: result,
                reference: refName,
                score: ScoreData(value: result.score, attempts: result.attempts ?? 1),
              ),
            );
          },
        );
      },
    );
  }
}
