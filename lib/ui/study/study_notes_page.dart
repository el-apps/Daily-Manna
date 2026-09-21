import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/study/study_notes_list.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class StudyNotesPage extends StatefulWidget {
  const StudyNotesPage({super.key});

  @override
  State<StudyNotesPage> createState() => _StudyNotesPageState();
}

class _StudyNotesPageState extends State<StudyNotesPage> {
  final _searchController = TextEditingController();
  ScriptureRangeRef? _passageFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<StudyNotesService>();
    return AppScaffold(
      title: 'Study Notes',
      showShareButton: false,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search study notes by title',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _choosePassage,
                icon: const Icon(Icons.menu_book),
                label: Text(
                  _passageFilter == null ? 'Find by passage' : 'Passage filter',
                ),
              ),
            ),
          ),
          if (_passageFilter != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InputChip(
                  label: Text(_passageName(context, _passageFilter!)),
                  onDeleted: () => setState(() => _passageFilter = null),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<db.StudyNote>>(
              stream: service.watchNotes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final notes = snapshot.data ?? const <db.StudyNote>[];
                return StudyNotesList(
                  notes: notes,
                  titleQuery: _searchController.text,
                  passage: _passageFilter,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNote,
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }

  Future<void> _choosePassage() async {
    final passage = await showPassageSelector(context);
    if (mounted && passage != null) setState(() => _passageFilter = passage);
  }

  Future<void> _createNote() async {
    final notesService = context.read<StudyNotesService>();
    final resultsService = context.read<ResultsService>();
    final passage = await showPassageSelector(context);
    if (!mounted || passage == null) return;
    final title = await _askForTitle();
    if (!mounted || title == null || title.trim().isEmpty) return;
    final note = await notesService.createNote(title: title, passage: passage);
    await resultsService.addStudyResult(passage);
    if (mounted) context.push('/study-notes/${note.id}', extra: note);
  }

  Future<String?> _askForTitle() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New study note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
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
    return title;
  }

  String _passageName(BuildContext context, ScriptureRangeRef passage) =>
      context.read<BibleService>().getRangeRefName(passage);
}

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
            Text('Notes related to this passage'),
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
