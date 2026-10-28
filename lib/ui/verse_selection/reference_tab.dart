import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/reading_reference_parser.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReferenceTab extends StatefulWidget {
  const ReferenceTab({
    super.key,
    required this.onSelected,
    this.rangeMode = true,
    this.onLogReading,
  });

  final ValueChanged<ScriptureRangeRef> onSelected;
  final bool rangeMode;
  final Future<void> Function(List<ReadingPassage>)? onLogReading;

  @override
  State<ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends State<ReferenceTab> {
  final _input = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.read<BibleService>();
    var passages = <ReadingPassage>[];
    String? parseError;
    try {
      passages = ReadingReferenceParser(bible).parse(_input.text);
    } on FormatException catch (error) {
      parseError = error.message;
    }
    final passage = passages.length == 1 ? passages.single : null;
    // Existing selector consumers accept one chapter range (or one verse).
    // Never discard extra passages or silently shorten a cross-chapter range.
    final canSelect =
        passage != null &&
        passage.startChapter == passage.endChapter &&
        (widget.rangeMode || passage.startVerse == passage.endVerse);
    final VoidCallback? select = _saving || !canSelect
        ? null
        : () => widget.onSelected(
            ScriptureRangeRef(
              bookId: passage.bookId,
              chapter: passage.startChapter,
              startVerse: passage.startVerse,
              endVerse: passage.endVerse,
            ),
          );
    final selectLabel = widget.rangeMode ? 'Select passage' : 'Select verse';
    final example = widget.onLogReading != null
        ? 'Deut 1–4'
        : widget.rangeMode
        ? 'John 3'
        : 'John 3:16';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              enabled: !_saving,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: 'Passage reference',
                hintText: 'e.g. $example',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() => _saveError = null),
            ),
            const SizedBox(height: 8),
            Text(
              widget.onLogReading != null
                  ? 'Chapters, verses, or several passages separated by commas.'
                  : widget.rangeMode
                  ? 'Enter a chapter or verse range. Abbreviations work.'
                  : 'Enter one verse. Abbreviations work.',
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (parseError != null)
                    Text(
                      parseError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (passages.isEmpty)
                    const Text('Enter a reference to preview the passage.')
                  else
                    for (final passage in passages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          bible.getReadingName(
                            bookId: passage.bookId,
                            startChapter: passage.startChapter,
                            startVerse: passage.startVerse,
                            endChapter: passage.endChapter,
                            endVerse: passage.endVerse,
                          ),
                        ),
                      ),
                ],
              ),
            ),
            if (passages.isNotEmpty && !canSelect) ...[
              const SizedBox(height: 12),
              Text(
                widget.rangeMode
                    ? 'To select a passage, enter one chapter or a verse range '
                          'within a chapter.'
                    : 'To select a verse, enter one verse, such as John 3:16.',
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (widget.onLogReading != null) ...[
              FilledButton(
                onPressed: _saving || passages.isEmpty
                    ? null
                    : () => _logReading(passages),
                child: Text(_saving ? 'Logging…' : 'Log reading'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: select, child: Text(selectLabel)),
            ] else
              FilledButton(onPressed: select, child: Text(selectLabel)),
          ],
        ),
      ),
    );
  }

  Future<void> _logReading(List<ReadingPassage> passages) async {
    setState(() => _saving = true);
    try {
      await widget.onLogReading!(passages);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Could not log the reading. Your reference is still here; try again.';
      });
    }
  }
}
