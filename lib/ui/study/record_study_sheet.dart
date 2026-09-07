import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/verse_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordStudySheet extends StatefulWidget {
  const RecordStudySheet({super.key, this.initialPassage});

  final ScriptureRangeRef? initialPassage;

  @override
  State<RecordStudySheet> createState() => _RecordStudySheetState();
}

class _RecordStudySheetState extends State<RecordStudySheet> {
  ScriptureRangeRef? _passage;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _passage = widget.initialPassage;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              'Log study session',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            VerseSelector.range(
              rangeRef:
                  _passage ??
                  const ScriptureRangeRef(
                    bookId: '',
                    chapter: 0,
                    startVerse: 0,
                  ),
              onRangeSelected: (ref) => setState(() => _passage = ref),
            ),
            TextField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'What stood out to you?',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _passage?.complete == true ? _save : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    await context.read<ResultsService>().addStudyResult(
      _passage!,
      notes: _notes.text.isEmpty ? null : _notes.text,
    );
    if (mounted) Navigator.pop(context);
  }
}
