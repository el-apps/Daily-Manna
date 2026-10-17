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
  bool _saving = false;

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
              'Record study session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose an existing note, create one, or record without a note.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : () => _startSession(null),
              icon: const Icon(Icons.check),
              label: const Text('Record without a note'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _saving ? null : _createNote,
              icon: const Icon(Icons.add),
              label: const Text('Create new study note'),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<db.StudyNote>>(
              stream: service.watchNotes(),
              builder: (context, snapshot) {
                final notes = snapshot.data ?? const <db.StudyNote>[];
                final related = notes
                    .where(
                      (note) => service
                          .passagesFor(note)
                          .any(
                            (reference) => reference.overlaps(widget.passage),
                          ),
                    )
                    .toList();
                final other = notes
                    .where((note) => !related.contains(note))
                    .toList();
                if (notes.isEmpty) return const SizedBox.shrink();
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in [
                        (label: 'Related notes', notes: related),
                        (label: 'Other notes', notes: other),
                      ]) ...[
                        if (group.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              group.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        for (final note in group.notes)
                          ListTile(
                            title: Text(note.title),
                            leading: const Icon(Icons.sticky_note_2_outlined),
                            onTap: _saving ? null : () => _startSession(note),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession(db.StudyNote? note) async {
    if (_saving) return;
    setState(() => _saving = true);
    final resultsService = context.read<ResultsService>();
    final notesService = context.read<StudyNotesService>();
    if (note != null) {
      await notesService.addPassage(note.id, widget.passage);
      note = await notesService.getNote(note.id);
    }
    await resultsService.addStudyResult(
      widget.passage,
      studyNoteId: note?.clientId,
    );
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, note);
      messenger.showSnackBar(
        const SnackBar(content: Text('Study session recorded')),
      );
    }
  }

  Future<void> _createNote() async {
    if (_saving) return;
    setState(() => _saving = true);
    final notesService = context.read<StudyNotesService>();
    var enteredTitle = '';
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New study note'),
        content: TextField(
          onChanged: (value) => enteredTitle = value,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, enteredTitle),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (title == null || title.trim().isEmpty) {
      setState(() => _saving = false);
      return;
    }
    final note = await notesService.createNote(
      title: title,
      passage: widget.passage,
    );
    if (mounted) {
      setState(() => _saving = false);
      await _startSession(note);
    }
  }
}
