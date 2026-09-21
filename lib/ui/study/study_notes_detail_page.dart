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
import 'package:provider/provider.dart';

/// Persistent workspace for a titled study note.
class StudyNotesDetailPage extends StatefulWidget {
  const StudyNotesDetailPage({super.key, required this.note});

  final db.StudyNote note;

  @override
  State<StudyNotesDetailPage> createState() => _StudyNotesDetailPageState();
}

class _StudyNotesDetailPageState extends State<StudyNotesDetailPage> {
  late String? _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.note.notes;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<StudyNotesService>();
    final bibleService = context.read<BibleService>();
    final passages = service.passagesFor(widget.note);
    final hasNotes = _notes?.isNotEmpty == true;

    return AppScaffold(
      title: widget.note.title,
      showShareButton: false,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Notes'),
                Tab(text: 'Concept Map'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _NotesTab(
                    notes: _notes,
                    passages: passages,
                    bibleService: bibleService,
                  ),
                  const _ConceptMapPlaceholder(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEditDialog,
        icon: const Icon(Icons.edit),
        label: Text(hasNotes ? 'Edit notes' : 'Add notes'),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final controller = TextEditingController(text: _notes);
    final newNotes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit notes'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 10,
          minLines: 5,
          decoration: const InputDecoration(
            hintText: 'What stood out to you?',
            alignLabelWithHint: true,
          ),
        ),
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
      await context.read<StudyNotesService>().updateNotes(
        widget.note.id,
        newNotes.isEmpty ? null : newNotes,
      );
      setState(() => _notes = newNotes);
    }
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({
    required this.notes,
    required this.passages,
    required this.bibleService,
  });

  final String? notes;
  final List passages;
  final BibleService bibleService;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (passages.isNotEmpty) ...[
        Text('Passages', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: passages
              .map(
                (passage) => Chip(
                  avatar: const Icon(Icons.menu_book, size: 18),
                  label: Text(bibleService.getRangeRefName(passage.ref)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
      if (notes?.isNotEmpty == true)
        Text(notes!, style: Theme.of(context).textTheme.bodyLarge)
      else
        const EmptyState(
          icon: Icons.edit_note,
          message: 'No notes recorded yet',
        ),
    ],
  );
}

class _ConceptMapPlaceholder extends StatelessWidget {
  const _ConceptMapPlaceholder();

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.account_tree_outlined,
    message: 'Concept maps are coming next.\nYour tracked passages are ready.',
  );
}

/// Legacy detail view for study-session history entries created before study
/// notes became persistent workspaces.
class StudyResultDetailPage extends StatefulWidget {
  const StudyResultDetailPage({super.key, required this.result});

  final db.Result result;

  @override
  State<StudyResultDetailPage> createState() => _StudyResultDetailPageState();
}

class _StudyResultDetailPageState extends State<StudyResultDetailPage> {
  late String? _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.result.notes;
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
                if (hasNotes)
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
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _showEditDialog,
                      child: Text(hasNotes ? 'Edit Notes' : 'Add Notes'),
                    ),
                  ),
                  const SizedBox(width: 16),
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
