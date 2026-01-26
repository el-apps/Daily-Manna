import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Page for viewing and editing study notes for a specific result.
class StudyNotesDetailPage extends StatefulWidget {
  const StudyNotesDetailPage({super.key, required this.result});

  final Result result;

  @override
  State<StudyNotesDetailPage> createState() => _StudyNotesDetailPageState();
}

class _StudyNotesDetailPageState extends State<StudyNotesDetailPage> {
  late String? _notes;

  @override
  void initState() {
    super.initState();
    _notes = widget.result.notes;
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final refName = bibleService.getRangeRefName(ScriptureRangeRef(
      bookId: widget.result.bookId,
      chapter: widget.result.startChapter,
      startVerse: widget.result.startVerse,
      endVerse: widget.result.endVerse,
    ));
    final dateTime = DateFormat.yMMMd().add_jm().format(widget.result.timestamp);
    final hasNotes = _notes != null && _notes!.isNotEmpty;

    return AppScaffold(
      title: 'Study Notes',
      showShareButton: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateTime,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  if (hasNotes)
                    Text(
                      _notes!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else
                    const EmptyState(
                      icon: Icons.edit_note,
                      message: 'No notes recorded',
                    ),
                ],
              ),
            ),
          ),
          _ButtonBar(
            hasNotes: hasNotes,
            onEditPressed: _showEditDialog,
            onPracticePressed: _showPracticeDialog,
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
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your notes...',
            border: OutlineInputBorder(),
          ),
          maxLines: 8,
          minLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newNotes != null && mounted) {
      await context
          .read<AppDatabase>()
          .updateResultNotes(widget.result.id, newNotes);
      setState(() => _notes = newNotes);
    }
  }

  void _showPracticeDialog() {
    showPracticeModeDialog(
      context,
      ScriptureRef(
        bookId: widget.result.bookId,
        chapterNumber: widget.result.startChapter,
        verseNumber: widget.result.startVerse,
      ),
    );
  }
}

class _ButtonBar extends StatelessWidget {
  const _ButtonBar({
    required this.hasNotes,
    required this.onEditPressed,
    required this.onPracticePressed,
  });

  final bool hasNotes;
  final VoidCallback onEditPressed;
  final VoidCallback onPracticePressed;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onEditPressed,
                  child: Text(hasNotes ? 'Edit Notes' : 'Add Notes'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: onPracticePressed,
                  child: const Text('Practice'),
                ),
              ),
            ],
          ),
        ),
      );
}
