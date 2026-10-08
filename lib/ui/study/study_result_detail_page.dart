import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/interaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Session history, including a link to its optional persistent study note.
class StudyResultDetailPage extends StatefulWidget {
  const StudyResultDetailPage({super.key, required this.result});

  final db.Result result;

  @override
  State<StudyResultDetailPage> createState() => _StudyResultDetailPageState();
}

class _StudyResultDetailPageState extends State<StudyResultDetailPage> {
  late String? _notes;
  Future<db.StudyNote?>? _linkedNote;

  @override
  void initState() {
    super.initState();
    _notes = widget.result.notes;
    final noteId = widget.result.studyNoteId;
    if (noteId != null) {
      _linkedNote = context.read<StudyNotesService>().getNoteByClientId(noteId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final ref = ScriptureRangeRef(
      bookId: widget.result.bookId,
      chapter: widget.result.startChapter,
      startVerse: widget.result.startVerse,
      endVerse: widget.result.endVerse,
    );
    final hasNotes = _notes?.isNotEmpty == true;
    return AppScaffold(
      title: 'Study Session',
      showShareButton: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  bibleService.getRangeRefName(ref),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat.yMMMd().add_jm().format(widget.result.timestamp),
                ),
                const SizedBox(height: 24),
                if (_linkedNote != null)
                  FutureBuilder<db.StudyNote?>(
                    future: _linkedNote,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final note = snapshot.data;
                      if (note == null) {
                        return const Text(
                          'The linked study note is not available on this device yet.',
                        );
                      }
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.sticky_note_2_outlined),
                          title: Text(note.title),
                          subtitle: const Text('Open study note'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/study-notes/${note.id}',
                            extra: note,
                          ),
                        ),
                      );
                    },
                  )
                else if (hasNotes)
                  Text(_notes!, style: Theme.of(context).textTheme.bodyLarge)
                else
                  const EmptyState(
                    icon: Icons.edit_note,
                    message: 'No notes recorded',
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_linkedNote == null) ...[
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _showEditDialog,
                        child: Text(hasNotes ? 'Edit Notes' : 'Add Notes'),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: () => showInteractionSheet(
                        context,
                        ScriptureRef(
                          bookId: widget.result.bookId,
                          chapterNumber: widget.result.startChapter,
                          verseNumber: widget.result.startVerse,
                        ),
                      ),
                      child: const Text('Interact'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: _notes);
    final newNotes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(controller: controller, maxLines: 8, minLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newNotes != null && mounted) {
      await context.read<ResultsService>().updateNotes(
        widget.result.id,
        newNotes,
      );
      setState(() => _notes = newNotes);
    }
  }
}
