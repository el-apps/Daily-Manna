import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/study/concept_map_editor.dart';
import 'package:daily_manna/ui/study/study_edit_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Persistent workspace for a titled study note.
class StudyNotesDetailPage extends StatefulWidget {
  const StudyNotesDetailPage({super.key, required this.note});

  final db.StudyNote note;

  @override
  State<StudyNotesDetailPage> createState() => _StudyNotesDetailPageState();
}

class _StudyNotesDetailPageState extends State<StudyNotesDetailPage>
    with SingleTickerProviderStateMixin {
  late String? _notes;
  late final TextEditingController _notesController;
  late ConceptMapDocument _conceptMap;
  late final TabController _tabController;
  final _conceptMapKey = GlobalKey<ConceptMapEditorState>();
  bool _isEditing = false;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _notes = widget.note.notes;
    _notesController = TextEditingController(text: _notes);
    _conceptMap = ConceptMapDocument.fromMermaid(widget.note.conceptMap ?? '');
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) {
          setState(() => _activeTab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _tabController.dispose();
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
      appBarActions: _isEditing
          ? null
          : [
              IconButton(
                onPressed: _enterEditMode,
                tooltip: 'Edit',
                icon: const Icon(Icons.edit),
              ),
            ],
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Concept Map'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              // The concept map owns horizontal gestures for panning. Tabs are
              // switched explicitly so a map swipe cannot leave the editor.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _NotesTab(
                  notes: _notes,
                  notesController: _notesController,
                  isEditing: _isEditing,
                  passages: passages,
                  bibleService: bibleService,
                ),
                ConceptMapEditor(
                  key: _conceptMapKey,
                  document: _conceptMap,
                  editing: _isEditing,
                  onChanged: (document) =>
                      setState(() => _conceptMap = document),
                ),
              ],
            ),
          ),
          if (_isEditing) _buildEditToolbar(),
        ],
      ),
    );
  }

  void _enterEditMode() => setState(() => _isEditing = true);

  Future<void> _save() async {
    final newNotes = _notesController.text;
    final service = context.read<StudyNotesService>();
    await service.updateNotes(
      widget.note.id,
      newNotes.isEmpty ? null : newNotes,
    );
    await service.updateConceptMap(widget.note.id, _conceptMap.toMermaid());
    if (mounted) {
      setState(() {
        _notes = newNotes;
        _isEditing = false;
      });
    }
  }

  Widget _buildEditToolbar() => StudyEditToolbar(
    actions: _activeTab == 0
        ? [
            IconButton(
              tooltip: 'Decrease heading',
              onPressed: () => _adjustHeading(-1),
              icon: const Icon(Icons.title),
            ),
            IconButton(
              tooltip: 'Increase heading',
              onPressed: () => _adjustHeading(1),
              icon: const Icon(Icons.format_size),
            ),
            IconButton(
              tooltip: 'Decrease bullet indent',
              onPressed: () => _adjustBullets(-1),
              icon: const Icon(Icons.format_indent_decrease),
            ),
            IconButton(
              tooltip: 'Increase bullet indent',
              onPressed: () => _adjustBullets(1),
              icon: const Icon(Icons.format_indent_increase),
            ),
          ]
        : [
            IconButton(
              tooltip: 'Add box',
              onPressed: () => _conceptMapKey.currentState?.addNodeMenu(),
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: 'Connect boxes',
              onPressed: () => _conceptMapKey.currentState?.startConnecting(),
              icon: const Icon(Icons.account_tree_outlined),
            ),
          ],
    onSave: _save,
  );

  void _adjustLine(String Function(String) update) {
    final value = _notesController.value;
    final text = value.text;
    final offset = value.selection.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final lineEnd = text.indexOf('\n', offset);
    final end = lineEnd == -1 ? text.length : lineEnd;
    final updated = update(text.substring(lineStart, end));
    _notesController.value = value.copyWith(
      text: text.replaceRange(lineStart, end, updated),
      selection: TextSelection.collapsed(offset: lineStart + updated.length),
    );
  }

  void _adjustHeading(int delta) => _adjustLine((line) {
    final content = line.replaceFirst(RegExp(r'^#{1,3}\s?'), '');
    final current = line.startsWith('#')
        ? RegExp(r'^#+').firstMatch(line)!.group(0)!.length
        : 0;
    final level = (current + delta).clamp(0, 3);
    return '${level == 0 ? '' : '${'#' * level} '}$content';
  });

  void _adjustBullets(int delta) => _adjustLine((line) {
    final content = line.replaceFirst(RegExp(r'^(  ){0,3}-\s?'), '');
    final match = RegExp(r'^(  +)-\s').firstMatch(line);
    final current = match == null ? (line.startsWith('- ') ? 1 : 0) :
        (match.group(1)!.length ~/ 2) + 1;
    final level = (current + delta).clamp(0, 3);
    return '${level == 0 ? '' : '${'  ' * (level - 1)}- '}$content';
  });
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
        _MarkdownPreview(notes!)
      else
        const EmptyState(
          icon: Icons.edit_note,
          message: 'No notes recorded yet',
        ),
    ],
  );

}

class _MarkdownPreview extends StatelessWidget {
  const _MarkdownPreview(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: source.split('\n').map((line) {
        final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
        if (heading != null) {
          final size = [0.0, 24.0, 20.0, 17.0][heading.group(1)!.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              heading.group(2)!,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: size),
            ),
          );
        }
        final bullet = RegExp(r'^(  ){0,2}-\s+(.*)$').firstMatch(line);
        if (bullet != null) {
          final indent = ((bullet.group(1)?.length ?? 0) * 16).toDouble();
          return Padding(
            padding: EdgeInsets.only(left: indent, bottom: 4),
            child: Text('• ${bullet.group(2)}'),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line, style: theme.textTheme.bodyLarge),
        );
      }).toList(),
    );
  }
}
