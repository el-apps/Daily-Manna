import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:flutter/material.dart';
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
  late final TextEditingController _notesController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _notes = widget.note.notes;
    _notesController = TextEditingController(text: _notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<StudyNotesService>();
    final bibleService = context.read<BibleService>();
    final passages = service.passagesFor(widget.note);

    return AppScaffold(
      title: widget.note.title,
      showShareButton: false,
      appBarActions: [
        IconButton(
          onPressed: _toggleEditMode,
          tooltip: _isEditing ? 'Save' : 'Edit',
          icon: Icon(_isEditing ? Icons.check : Icons.edit),
        ),
      ],
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
                    notesController: _notesController,
                    isEditing: _isEditing,
                    passages: passages,
                    bibleService: bibleService,
                  ),
                  _ConceptMapPlaceholder(isEditing: _isEditing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleEditMode() async {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      return;
    }

    final newNotes = _notesController.text;
    await context.read<StudyNotesService>().updateNotes(
      widget.note.id,
      newNotes.isEmpty ? null : newNotes,
    );
    if (mounted) {
      setState(() {
        _notes = newNotes;
        _isEditing = false;
      });
    }
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({
    required this.notes,
    required this.notesController,
    required this.isEditing,
    required this.passages,
    required this.bibleService,
  });

  final String? notes;
  final TextEditingController notesController;
  final bool isEditing;
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
                  label: Text(bibleService.getRangeRefName(passage)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
      ],
      if (isEditing)
        TextField(
          controller: notesController,
          autofocus: true,
          maxLines: null,
          minLines: 10,
          decoration: const InputDecoration(
            hintText: 'What stood out to you?',
            alignLabelWithHint: true,
          ),
        )
      else if (notes?.isNotEmpty == true)
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
  const _ConceptMapPlaceholder({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.account_tree_outlined,
    message: isEditing
        ? 'Concept map editing will appear here.'
        : 'Concept maps are coming next.\nYour tracked passages are ready.',
  );
}
