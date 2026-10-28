import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/reading_reference_parser.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReferenceTab extends StatefulWidget {
  const ReferenceTab({
    super.key,
    required this.onChanged,
    this.rangeMode = true,
  });

  final ValueChanged<ScriptureRangeRef?> onChanged;
  final bool rangeMode;

  @override
  State<ReferenceTab> createState() => _ReferenceTabState();
}

class _ReferenceTabState extends State<ReferenceTab>
    with AutomaticKeepAliveClientMixin {
  List<ReadingPassage> _passages = [];
  String? _parseError;

  @override
  bool get wantKeepAlive => true;

  ScriptureRangeRef? get _selection {
    final passage = _passages.length == 1 ? _passages.single : null;
    // Existing selector consumers accept one chapter range (or one verse).
    // Never discard extra passages or silently shorten a cross-chapter range.
    if (passage == null ||
        passage.startChapter != passage.endChapter ||
        (!widget.rangeMode && passage.startVerse != passage.endVerse)) {
      return null;
    }
    return ScriptureRangeRef(
      bookId: passage.bookId,
      chapter: passage.startChapter,
      startVerse: passage.startVerse,
      endVerse: passage.endVerse,
    );
  }

  void _updateReference(String input) {
    var passages = <ReadingPassage>[];
    String? error;
    try {
      passages = ReadingReferenceParser(
        context.read<BibleService>(),
      ).parse(input);
    } on FormatException catch (exception) {
      error = exception.message;
    }
    setState(() {
      _passages = passages;
      _parseError = error;
    });
    widget.onChanged(_selection);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bible = context.read<BibleService>();
    final example = widget.rangeMode ? 'John 3' : 'John 3:16';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              autofocus: true,
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
              onChanged: _updateReference,
            ),
            const SizedBox(height: 8),
            Text(
              widget.rangeMode
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
                  if (_parseError != null)
                    Text(
                      _parseError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (_passages.isEmpty)
                    const Text('Enter a reference to preview the passage.')
                  else
                    for (final passage in _passages)
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
            if (_passages.isNotEmpty && _selection == null) ...[
              const SizedBox(height: 12),
              Text(
                widget.rangeMode
                    ? 'To select a passage, enter one chapter or a verse range '
                          'within a chapter.'
                    : 'To select a verse, enter one verse, such as John 3:16.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
