import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/verse_selector.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EngageActions extends StatelessWidget {
  const EngageActions({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _practiceAnyVerse(context),
            icon: const Icon(Icons.add),
            label: const Text('Start verse'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showStudyDialog(context),
            icon: const Icon(Icons.menu_book),
            label: const Text('Log study'),
          ),
        ),
      ],
    ),
  );

  Future<void> _practiceAnyVerse(BuildContext context) async {
    final ref = await Navigator.of(context).push<ScriptureRef>(
      MaterialPageRoute(builder: (_) => const VerseSelectionPage()),
    );
    if (context.mounted && ref != null) showPracticeModeDialog(context, ref);
  }

  void _showStudyDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const StudyLogDialog());
  }
}

class StudyLogDialog extends StatefulWidget {
  const StudyLogDialog({super.key});

  @override
  State<StudyLogDialog> createState() => _StudyLogDialogState();
}

class _StudyLogDialogState extends State<StudyLogDialog> {
  ScriptureRangeRef? _passage;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Log study session'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VerseSelector.range(
          rangeRef:
              _passage ??
              const ScriptureRangeRef(bookId: '', chapter: 0, startVerse: 0),
          onRangeSelected: (ref) => setState(() => _passage = ref),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _passage?.complete == true ? _save : null,
        child: const Text('Save'),
      ),
    ],
  );

  Future<void> _save() async {
    await context.read<ResultsService>().addStudyResult(
      _passage!,
      notes: _notes.text.isEmpty ? null : _notes.text,
    );
    if (mounted) Navigator.pop(context);
  }
}
