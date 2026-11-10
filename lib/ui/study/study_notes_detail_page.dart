import 'dart:async';
import 'dart:convert';

import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/services/study_notes_pdf.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/study/concept_map_editor.dart';
import 'package:daily_manna/ui/study/study_markdown_preview.dart';
import 'package:daily_manna/ui/study/study_notes_pdf_dialog.dart';
import 'package:daily_manna/ui/study/study_note_title_dialog.dart';
import 'package:daily_manna/ui/edit_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

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
  late String _savedConceptMap;
  late final TabController _tabController;
  final _conceptMapKey = GlobalKey<ConceptMapEditorState>();
  bool _isEditing = false;
  bool _exporting = false;
  late bool _archived;
  late String _title;
  String? _selectedMapNodeId;
  int _activeTab = 0;
  SharedPreferences? _draftPreferences;
  late final Future<void> _draftReady;
  late final StreamSubscription<db.StudyNote?> _noteSubscription;
  bool _saving = false;
  String? _draftMessage;
  Future<bool>? _draftWrite;
  bool _unknownDraftBaseline = false;

  String get _draftKey => 'study_note_draft_${widget.note.clientId}';

  @override
  void initState() {
    super.initState();
    _notes = widget.note.notes;
    _archived = widget.note.archived;
    _title = widget.note.title;
    _notesController = TextEditingController(text: _notes);
    _conceptMap = ConceptMapDocument.fromMermaid(widget.note.conceptMap ?? '');
    _savedConceptMap = _conceptMap.toMermaid();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging && mounted) {
          setState(() => _activeTab = _tabController.index);
        }
      });
    _draftReady = _restoreDraft();
    _noteSubscription = context
        .read<StudyNotesService>()
        .watchNote(widget.note.id)
        .listen((note) {
          // Never replace an open draft or change its baseline underneath it.
          if (!mounted || note == null || _isEditing || _saving) return;
          setState(() {
            _notes = note.notes;
            _notesController.text = note.notes ?? '';
            _title = note.title;
            _archived = note.archived;
            _conceptMap = ConceptMapDocument.fromMermaid(note.conceptMap ?? '');
            _savedConceptMap = _conceptMap.toMermaid();
          });
        });
  }

  Future<void> _restoreDraft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _draftPreferences = preferences;
      final raw = preferences.getString(_draftKey);
      if (raw != null) {
        final draft = jsonDecode(raw) as Map<String, dynamic>;
        // Old drafts have no baseline; preserve the current synced version on save.
        _unknownDraftBaseline =
            draft['unknownBaseline'] == true ||
            (draft.containsKey('notes') && !draft.containsKey('baseNotes')) ||
            (draft.containsKey('conceptMap') &&
                !draft.containsKey('baseConceptMap'));
        if (draft.containsKey('baseNotes')) {
          _notes = draft['baseNotes'] as String?;
        }
        if (draft.containsKey('baseConceptMap')) {
          _savedConceptMap = draft['baseConceptMap'] as String;
        }
        _notesController.text = draft['notes'] as String? ?? _notes ?? '';
        _conceptMap = ConceptMapDocument.fromMermaid(
          draft['conceptMap'] as String? ?? _savedConceptMap,
        );
        _isEditing = true;
        _draftMessage = 'Local draft restored. Save to sync your changes.';
      }
    } catch (_) {
      _draftMessage =
          'Could not recover the local draft. Please save manually.';
    }
    if (!mounted) return;
    _notesController.addListener(_persistDraft);
    setState(() {});
  }

  void _persistDraft() {
    if (!_isEditing || _saving) return;
    final preferences = _draftPreferences;
    if (preferences == null) return;
    final notes = _notesController.text;
    final map = _conceptMap.toMermaid();
    // Store only edited fields so recovering a draft preserves other synced edits.
    final draft = <String, Object?>{
      if (notes != (_notes ?? '')) ...{'notes': notes, 'baseNotes': _notes},
      if (map != _savedConceptMap) ...{
        'conceptMap': map,
        'baseConceptMap': _savedConceptMap,
      },
    };
    if (draft.isNotEmpty && _unknownDraftBaseline) {
      draft['unknownBaseline'] = true;
    }
    _draftWrite = draft.isEmpty
        ? preferences.remove(_draftKey)
        : preferences.setString(_draftKey, jsonEncode(draft));
    _draftWrite!.then((saved) {
      if (!saved) _draftFailed();
    }, onError: (Object _) => _draftFailed());
  }

  void _draftFailed() {
    if (!mounted) return;
    setState(() {
      _draftMessage =
          'Could not protect the local draft. Please save manually.';
    });
  }

  void _changeConceptMap(ConceptMapDocument document) {
    setState(() => _conceptMap = document);
    _persistDraft();
  }

  @override
  void dispose() {
    _noteSubscription.cancel();
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: _saving,
    child: AppScaffold(
      title: _title,
      showShareButton: false,
      appBarActions: [
        IconButton(
          tooltip: _exporting ? 'Generating PDF…' : 'Generate PDF',
          onPressed: _exporting ? null : _exportPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
        if (!_isEditing)
          PopupMenuButton<String>(
            tooltip: 'Note actions',
            onSelected: (action) {
              if (action == 'rename') {
                _rename();
              } else {
                _setArchived(!_archived);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename note')),
              PopupMenuItem(
                value: 'archive',
                child: Text(_archived ? 'Restore note' : 'Archive note'),
              ),
            ],
          ),
      ],
      floatingActionButton: _isEditing
          ? null
          : _buildEditToolbar(editing: false),
      body: Column(
        children: [
          if (_draftMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Semantics(liveRegion: true, child: Text(_draftMessage!)),
            ),
          if (_archived)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(
                avatar: Icon(Icons.archive_outlined),
                label: Text('Archived'),
              ),
            ),
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
                  onBold: _bold,
                  onIndent: () => _adjustBullets(1),
                  onDedent: () => _adjustBullets(-1),
                ),
                ConceptMapEditor(
                  key: _conceptMapKey,
                  document: _conceptMap,
                  editing: _isEditing,
                  selectedNodeId: _selectedMapNodeId,
                  onNodeSelected: (id) =>
                      setState(() => _selectedMapNodeId = id),
                  onChanged: _changeConceptMap,
                ),
              ],
            ),
          ),
          if (_isEditing) _buildEditToolbar(editing: true),
        ],
      ),
    ),
  );

  Future<void> _enterEditMode() async {
    await _draftReady;
    if (mounted) setState(() => _isEditing = true);
  }

  Future<void> _exportPdf() async {
    final format = await showDialog<StudyNotesPdfFormat>(
      context: context,
      builder: (_) => const StudyNotesPdfDialog(),
    );
    if (format == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final files = await buildStudyNotesPdfs(
        title: _title,
        source: _notesController.text,
        format: format,
      );
      if (kIsWeb) {
        // Browser downloads do not need a registered native printing channel.
        for (final file in files.entries) {
          await XFile.fromData(
            file.value,
            name: file.key,
            mimeType: 'application/pdf',
          ).saveTo(file.key);
        }
      } else if (files.length == 1) {
        final file = files.entries.single;
        await Printing.sharePdf(bytes: file.value, filename: file.key);
      } else {
        // Share both manual-duplex files in one native share sheet.
        await SharePlus.instance.share(
          ShareParams(
            files: [
              for (final file in files.entries)
                XFile.fromData(file.value, mimeType: 'application/pdf'),
            ],
            fileNameOverrides: files.keys.toList(),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        context.read<ErrorLoggerService>().logError(
          'PDF export failed: $error',
          context: 'Study notes',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate PDF. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _setArchived(bool archived) async {
    await context.read<StudyNotesService>().setArchived(
      widget.note.id,
      archived,
    );
    if (!mounted) return;
    setState(() => _archived = archived);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            archived ? 'Study note archived' : 'Study note restored',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _setArchived(!archived),
          ),
        ),
      );
  }

  Future<void> _rename() async {
    final service = context.read<StudyNotesService>();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => StudyNoteTitleDialog(initialTitle: _title),
    );
    if (!mounted || title == null) return;
    await service.renameNote(widget.note.id, title);
    if (mounted) setState(() => _title = title);
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final newNotes = _notesController.text;
      final newMap = _conceptMap.toMermaid();
      // Compare with the loaded editor baseline, not a newer row from sync.
      final notes = newNotes == (_notes ?? '')
          ? const Value<String?>.absent()
          : Value<String?>(newNotes.isEmpty ? null : newNotes);
      final conceptMap = newMap == _savedConceptMap ? null : newMap;
      final service = context.read<StudyNotesService>();
      final preservedConflict = await service.saveNote(
        widget.note.id,
        notes: notes,
        conceptMap: conceptMap,
        previousNotes: Value(_notes),
        previousConceptMap: _savedConceptMap,
        preserveCurrentVersion: _unknownDraftBaseline,
      );
      final saved = await service.getNote(widget.note.id);
      if (saved == null) throw StateError('Study note no longer exists');
      await _draftWrite?.catchError((Object _) => false);
      _draftPreferences?.remove(_draftKey).then((removed) {
        if (!removed) _draftFailed();
      }, onError: (Object _) => _draftFailed());
      if (mounted) {
        setState(() {
          _notes = saved.notes;
          _notesController.text = saved.notes ?? '';
          _title = saved.title;
          _archived = saved.archived;
          _conceptMap = ConceptMapDocument.fromMermaid(saved.conceptMap ?? '');
          _savedConceptMap = _conceptMap.toMermaid();
          _isEditing = false;
          _selectedMapNodeId = null;
          _draftMessage = null;
          _unknownDraftBaseline = false;
        });
        if (preservedConflict) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Another version was kept as a conflict copy in Study Notes.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Your edits are still open. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildEditToolbar({required bool editing}) => EditToolbar(
    editing: editing,
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
            IconButton(
              tooltip: 'Bold (blue) · Ctrl+B / ⌘B',
              onPressed: _bold,
              icon: const Icon(Icons.format_bold),
            ),
            IconButton(
              tooltip: 'Blockquote',
              onPressed: () => _adjustLine(
                (line) => line.startsWith('> ') ? line.substring(2) : '> $line',
              ),
              icon: const Icon(Icons.format_quote),
            ),
            IconButton(
              tooltip: 'Page break',
              onPressed: () => _insert('\n\n\\newpage\n\n'),
              icon: const Icon(Icons.insert_page_break_outlined),
            ),
          ]
        : [
            TextButton.icon(
              onPressed: () => _conceptMapKey.currentState?.addNode(
                ConceptMapNodeType.keyPoint,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Key point'),
            ),
            TextButton.icon(
              onPressed: () => _conceptMapKey.currentState?.addNode(),
              icon: const Icon(Icons.add),
              label: const Text('Note'),
            ),
            TextButton.icon(
              onPressed: () => _conceptMapKey.currentState?.addPassage(),
              icon: const Icon(Icons.add),
              label: const Text('Passage'),
            ),
            for (final node in _conceptMap.nodes)
              if (node.id == _selectedMapNodeId) ...[
                const SizedBox(height: 24, child: VerticalDivider()),
                if (node.type == ConceptMapNodeType.passage)
                  TextButton.icon(
                    onPressed: () => _changeConceptMap(
                      _conceptMap.updateNode(
                        node.copyWith(showPassage: !node.showPassage),
                      ),
                    ),
                    icon: const Icon(Icons.article_outlined),
                    label: Text(
                      node.showPassage ? 'Hide passage' : 'Show passage',
                    ),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      _conceptMapKey.currentState?.startConnecting(node.id),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Connect'),
                ),
                TextButton.icon(
                  onPressed:
                      _conceptMap.edges.any(
                        (edge) => edge.from == node.id || edge.to == node.id,
                      )
                      ? () => _conceptMapKey.currentState?.removeConnection(
                          node.id,
                        )
                      : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
                if (node.type != ConceptMapNodeType.passage)
                  TextButton.icon(
                    onPressed: () => _changeConceptMap(
                      _conceptMap.updateNode(
                        node.copyWith(
                          type: node.type == ConceptMapNodeType.keyPoint
                              ? ConceptMapNodeType.note
                              : ConceptMapNodeType.keyPoint,
                        ),
                      ),
                    ),
                    icon: Icon(
                      node.type == ConceptMapNodeType.keyPoint
                          ? Icons.note_outlined
                          : Icons.star_outline,
                    ),
                    label: Text(
                      node.type == ConceptMapNodeType.keyPoint
                          ? 'Change to note'
                          : 'Change to key point',
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _conceptMap = _conceptMap.deleteNode(node.id);
                    _selectedMapNodeId = null;
                    _persistDraft();
                  }),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                for (final (offset, label, icon) in [
                  (-1, 'Move up', Icons.arrow_upward),
                  (1, 'Move down', Icons.arrow_downward),
                ])
                  IconButton(
                    tooltip: label,
                    onPressed:
                        identical(
                          conceptMapMoveNode(_conceptMap, node.id, offset),
                          _conceptMap,
                        )
                        ? null
                        : () => setState(() {
                            _conceptMap = conceptMapMoveNode(
                              _conceptMap,
                              node.id,
                              offset,
                            );
                            _persistDraft();
                          }),
                    icon: Icon(icon),
                  ),
              ],
          ],
    onEdit: _enterEditMode,
    onSave: _save,
  );

  void _adjustLine(
    String Function(String) update, {
    bool preserveSelection = false,
  }) {
    final value = _notesController.value;
    final text = value.text;
    final offset = value.selection.start.clamp(0, text.length);
    final selectedEnd = value.selection.end.clamp(offset, text.length);
    final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final endOffset = selectedEnd > offset && text[selectedEnd - 1] == '\n'
        ? selectedEnd - 1
        : selectedEnd;
    final lineEnd = text.indexOf('\n', endOffset);
    final end = lineEnd == -1 ? text.length : lineEnd;
    final lines = text.substring(lineStart, end).split('\n');
    final updatedLines = lines.map(update).toList();
    final updated = updatedLines.join('\n');
    int mapOffset(int position) {
      var oldStart = lineStart;
      var newStart = lineStart;
      for (var i = 0; i < lines.length; i++) {
        if (position <= oldStart + lines[i].length) {
          final delta = updatedLines[i].length - lines[i].length;
          return newStart +
              (position - oldStart + delta).clamp(0, updatedLines[i].length);
        }
        oldStart += lines[i].length + 1;
        newStart += updatedLines[i].length + 1;
      }
      return position + updated.length - (end - lineStart);
    }

    _notesController.value = value.copyWith(
      text: text.replaceRange(lineStart, end, updated),
      selection: preserveSelection
          ? TextSelection(
              baseOffset: mapOffset(value.selection.baseOffset),
              extentOffset: mapOffset(value.selection.extentOffset),
            )
          : TextSelection.collapsed(offset: lineStart + updated.length),
      composing: TextRange.empty,
    );
  }

  void _insert(String insertion) {
    final value = _notesController.value;
    final start = value.selection.start.clamp(0, value.text.length);
    final end = value.selection.end.clamp(start, value.text.length);
    _notesController.value = TextEditingValue(
      text: value.text.replaceRange(start, end, insertion),
      selection: TextSelection.collapsed(offset: start + insertion.length),
    );
  }

  void _bold() {
    // Switching tabs can leave the hidden Markdown field holding focus.
    if (!_isEditing || _activeTab != 0) return;
    final value = _notesController.value;
    final start = value.selection.start.clamp(0, value.text.length);
    final end = value.selection.end.clamp(start, value.text.length);
    final selected = value.text.substring(start, end);
    final content = selected.isEmpty ? 'bold text' : selected;
    _insert('**$content**');
    _notesController.selection = TextSelection(
      baseOffset: start + 2,
      extentOffset: start + 2 + content.length,
    );
  }

  void _adjustHeading(int delta) => _adjustLine((line) {
    final content = line.replaceFirst(RegExp(r'^#{1,6}\s?'), '');
    final current = line.startsWith('#')
        ? RegExp(r'^#+').firstMatch(line)!.group(0)!.length
        : 0;
    final level = (current + delta).clamp(0, 6);
    return '${level == 0 ? '' : '${'#' * level} '}$content';
  });

  void _adjustBullets(int delta) {
    if (!_isEditing || _activeTab != 0) return;
    _adjustLine((line) {
      final content = line.replaceFirst(RegExp(r'^\s*[-+*]\s+'), '');
      final match = RegExp(r'^( *)[-+*]\s+').firstMatch(line);
      final current = match == null ? 0 : (match.group(1)!.length ~/ 2) + 1;
      final level = (current + delta).clamp(0, 9);
      return '${level == 0 ? '' : '${'  ' * (level - 1)}- '}$content';
    }, preserveSelection: true);
  }
}

class _NotesTab extends StatefulWidget {
  const _NotesTab({
    required this.notes,
    required this.notesController,
    required this.isEditing,
    required this.onBold,
    required this.onIndent,
    required this.onDedent,
  });

  final String? notes;
  final TextEditingController notesController;
  final bool isEditing;
  final VoidCallback onBold;
  final VoidCallback onIndent;
  final VoidCallback onDedent;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _viewportKey = GlobalKey();
  final _editorKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _NotesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing && !oldWidget.isEditing) {
      widget.notesController.selection = TextSelection.collapsed(
        offset: _visibleSourceOffset(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealCursor());
    }
  }

  // Match rendered text spans in document order, not by scroll percentage:
  // headings, lists and wrapping have different heights in Markdown source.
  int _visibleSourceOffset() {
    final viewport =
        _viewportKey.currentContext!.findRenderObject() as RenderBox;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final source = widget.notesController.text;
    var sourceCursor = 0;
    int? anchor;

    void visit(RenderObject object) {
      if (anchor != null) return;
      if (object is RenderEditable) {
        final origin = object.localToGlobal(Offset.zero);
        final visible = origin.dy + object.size.height > top;
        final position = object
            .getPositionForPoint(
              Offset(
                origin.dx,
                top.clamp(origin.dy, origin.dy + object.size.height),
              ),
            )
            .offset;
        var textOffset = 0;
        object.text?.visitChildren((span) {
          if (span is! TextSpan || span.text == null) return true;
          final text = span.text!;
          // Markdown collapses source whitespace, so match words within each
          // literal span while skipping syntax such as emphasis and link URLs.
          for (final word in RegExp(r'\S+').allMatches(text)) {
            final content = word.group(0)!;
            final start = source.indexOf(content, sourceCursor);
            if (start < 0) continue;
            sourceCursor = start + content.length;
            final renderedStart = textOffset + word.start;
            if (visible &&
                anchor == null &&
                position < renderedStart + content.length) {
              anchor =
                  start + (position - renderedStart).clamp(0, content.length);
            }
          }
          textOffset += text.length;
          return true;
        });
        return;
      }
      object.visitChildren(visit);
    }

    viewport.visitChildren(visit);
    return anchor ?? 0;
  }

  void _revealCursor() {
    if (!mounted || !widget.isEditing) return;
    RenderEditable? editor;
    void visit(RenderObject object) {
      if (object is RenderEditable) {
        editor = object;
      } else {
        object.visitChildren(visit);
      }
    }

    _editorKey.currentContext!.findRenderObject()!.visitChildren(visit);
    if (editor != null && _scrollController.hasClients) {
      final viewport =
          _viewportKey.currentContext!.findRenderObject() as RenderBox;
      final caret = editor!.getLocalRectForCaret(
        widget.notesController.selection.extent,
      );
      final delta =
          editor!.localToGlobal(caret.topLeft).dy -
          viewport.localToGlobal(Offset.zero).dy -
          16;
      final position = _scrollController.position;
      _scrollController.jumpTo(
        (position.pixels + delta).clamp(0, position.maxScrollExtent),
      );
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: _viewportKey,
    controller: _scrollController,
    padding: const EdgeInsets.all(16),
    children: [
      if (widget.isEditing) ...[
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyB, control: true):
                widget.onBold,
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
                widget.onBold,
            const SingleActivator(LogicalKeyboardKey.tab): widget.onIndent,
            const SingleActivator(LogicalKeyboardKey.tab, shift: true):
                widget.onDedent,
          },
          child: TextField(
            key: _editorKey,
            controller: widget.notesController,
            focusNode: _focusNode,
            style: const TextStyle(fontFamily: 'DejaVuSansMono'),
            inputFormatters: [_BulletContinuationFormatter()],
            autofocus:
                widget.isEditing && !widget.notesController.selection.isValid,
            maxLines: null,
            minLines: 10,
            decoration: const InputDecoration(
              hintText:
                  '# Sermon title\n\n- Main point\n  - Supporting point\n\nRead James 1:9-11\n\n> Quotation',
              alignLabelWithHint: true,
            ),
          ),
        ),
      ] else if (widget.notes?.isNotEmpty == true)
        StudyMarkdownPreview(source: widget.notes!)
      else
        const EmptyState(
          icon: Icons.edit_note,
          message:
              'Start writing or add cards to your concept map.\n'
              'Saved changes record one study session per day.',
        ),
    ],
  );
}

/// Handles text input rather than only hardware Enter, including mobile keyboards.
class _BulletContinuationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final selection = oldValue.selection;
    if (!selection.isValid || !newValue.composing.isCollapsed) return newValue;
    final start = selection.start;
    final end = selection.end;
    // Leave paste, deletion, and other edits untouched.
    if (newValue.text != oldValue.text.replaceRange(start, end, '\n')) {
      return newValue;
    }
    final lineStart = start == 0
        ? 0
        : oldValue.text.lastIndexOf('\n', start - 1) + 1;
    final lineEnd = oldValue.text.indexOf('\n', end);
    final line = oldValue.text.substring(
      lineStart,
      lineEnd == -1 ? oldValue.text.length : lineEnd,
    );
    final bullet = RegExp(r'^( *[-+*] +)').firstMatch(line);
    if (bullet == null || start < lineStart + bullet.end) return newValue;
    final prefix = bullet.group(0)!;
    if (line.substring(bullet.end).trim().isEmpty) {
      return TextEditingValue(
        text: newValue.text.replaceRange(lineStart, start + 1, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }
    return TextEditingValue(
      text: newValue.text.replaceRange(start + 1, start + 1, prefix),
      selection: TextSelection.collapsed(offset: start + 1 + prefix.length),
    );
  }
}
