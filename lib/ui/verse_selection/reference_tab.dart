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
  });

  final ValueChanged<ScriptureRangeRef> onSelected;
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

  bool _canSelect(ReadingPassage passage) =>
      passage.startChapter == passage.endChapter &&
      (widget.rangeMode || passage.startVerse == passage.endVerse);

  void _updateReference(String input) {
    var passages = <ReadingPassage>[];
    String? error;
    try {
      passages = ReadingReferenceParser(
        context.read<BibleService>(),
      ).parse(input, includeAlternatives: true);
    } on FormatException catch (exception) {
      error = exception.message;
    }
    setState(() {
      _passages = passages;
      _parseError = error;
    });
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
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      errorText: _parseError,
                      errorMaxLines: 3,
                    ),
                    onChanged: _updateReference,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.rangeMode
                        ? 'Enter a chapter or verse range. Abbreviations work.'
                        : 'Enter one verse. Abbreviations work.',
                  ),
                ],
              ),
            ),
            if (_passages.any(_canSelect)) const Divider(),
            for (final passage in _passages)
              if (_canSelect(passage))
                ListTile(
                  title: Text(
                    bible.getReadingName(
                      bookId: passage.bookId,
                      startChapter: passage.startChapter,
                      startVerse: passage.startVerse,
                      endChapter: passage.endChapter,
                      endVerse: passage.endVerse,
                    ),
                  ),
                  onTap: () => widget.onSelected(
                    ScriptureRangeRef(
                      bookId: passage.bookId,
                      chapter: passage.startChapter,
                      startVerse: passage.startVerse,
                      endVerse: passage.endVerse,
                    ),
                  ),
                ),
            if (_passages.any((passage) => !_canSelect(passage))) ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  widget.rangeMode
                      ? 'To select a passage, enter one chapter or a verse range '
                            'within a chapter.'
                      : 'To select a verse, enter one verse, such as John 3:16.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
