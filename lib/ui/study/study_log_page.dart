import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
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
  Widget build(BuildContext context) => AppScaffold(
    title: 'Study Log',
    showShareButton: false,
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
  );

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
  Widget build(BuildContext context) => PassageRangeSelector(
    ref: selectedPassage ??
        const ScriptureRangeRef(bookId: '', chapter: 0, startVerse: 0),
    onSelected: onSelected,
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
    maxLines: 5,
    minLines: 3,
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
