import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudyNotePicker extends StatefulWidget {
  const StudyNotePicker({super.key, required this.passage});

  final ScriptureRangeRef passage;

  @override
  State<StudyNotePicker> createState() => _StudyNotePickerState();
}

class _StudyNotePickerState extends State<StudyNotePicker> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<StudyNotesService>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start study session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text('Notes related to this passage'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _createNote,
              icon: const Icon(Icons.add),
              label: const Text('Create new study note'),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<db.StudyNote>>(
              stream: service.watchNotes(),
              builder: (context, snapshot) {
                final notes = (snapshot.data ?? const <db.StudyNote>[])
                    .where(
                      (note) => service
                          .passagesFor(note)
                          .any(
                            (reference) => reference.overlaps(widget.passage),
                          ),
                    )
                    .toList();
                if (notes.isEmpty) return const SizedBox.shrink();
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: notes
                        .map(
                          (note) => ListTile(
                            title: Text(note.title),
                            leading: const Icon(Icons.sticky_note_2_outlined),
                            onTap: () => _startSession(note),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession(db.StudyNote note) async {
    final resultsService = context.read<ResultsService>();
    await resultsService.addStudyResult(widget.passage);
    if (mounted) Navigator.pop(context, note);
  }

  Future<void> _createNote() async {
    final notesService = context.read<StudyNotesService>();
    final resultsService = context.read<ResultsService>();
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New study note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || title == null || title.trim().isEmpty) return;
    final note = await notesService.createNote(
      title: title,
      passage: widget.passage,
    );
    await resultsService.addStudyResult(widget.passage);
    if (mounted) Navigator.pop(context, note);
  }
}
