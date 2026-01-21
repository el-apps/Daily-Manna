import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PassageRangeSelector extends StatelessWidget {
  final ScriptureRangeRef ref;
  final Function(ScriptureRangeRef) onSelected;

  const PassageRangeSelector({
    super.key,
    required this.ref,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    String displayText = 'Select passage';
    try {
      if (ref.complete) {
        displayText = bibleService.getRangeRefName(ref);
      }
    } catch (e) {
      debugPrint('[PassageRangeSelector] Error getting range ref name: $e');
      displayText = 'Select passage';
    }

    return ListTile(
      title: Text(displayText),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openSelectorDialog(context),
    );
  }

  void _openSelectorDialog(BuildContext context) async {
    final selectedRef = await showDialog<ScriptureRangeRef>(
      context: context,
      builder: (context) => _SelectPassageRangeDialog(ref: ref),
    );

    if (selectedRef != null) {
      onSelected(selectedRef);
    }
  }
}

class _SelectPassageRangeDialog extends StatefulWidget {
  final ScriptureRangeRef ref;

  const _SelectPassageRangeDialog({required this.ref});

  @override
  State<_SelectPassageRangeDialog> createState() =>
      _SelectPassageRangeDialogState();
}

class _SelectPassageRangeDialogState extends State<_SelectPassageRangeDialog> {
  late ScriptureRangeRef selected;

  @override
  void initState() {
    super.initState();
    selected = widget.ref;
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    return AlertDialog(
      title: const Text('Select Passage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            // Book selector
            DropdownMenu(
              width: double.infinity,
              initialSelection:
                  selected.bookId.isNotEmpty ? selected.bookId : null,
              label: const Text('Book'),
              dropdownMenuEntries: bibleService.books
                  .map<DropdownMenuEntry<String>>(
                    (book) =>
                        DropdownMenuEntry(value: book.id, label: book.title),
                  )
                  .toList(),
              onSelected: (bookId) => setState(
                () => selected = ScriptureRangeRef(
                  bookId: bookId ?? '',
                  chapter: 1,
                  startVerse: 1,
                ),
              ),
            ),

            if (selected.bookId.isNotEmpty) ...[
              // Chapter selector
              DropdownMenu(
                width: double.infinity,
                label: const Text('Chapter'),
                initialSelection: selected.chapter,
                dropdownMenuEntries:
                    (bibleService.getChapters(selected.bookId))
                        .map<DropdownMenuEntry<int>>(
                          (chapter) => DropdownMenuEntry(
                            value: chapter.num,
                            label: chapter.num.toString(),
                          ),
                        )
                        .toList(),
                onSelected: (chapterNumber) => setState(
                  () => selected = ScriptureRangeRef(
                    bookId: selected.bookId,
                    chapter: chapterNumber ?? 1,
                    startVerse: 1,
                  ),
                ),
              ),

              // Verse range selector
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Start Verse'),
                      initialSelection: selected.startVerse,
                      dropdownMenuEntries: (bibleService.getVerses(
                            selected.bookId,
                            selected.chapter,
                          ))
                          .map<DropdownMenuEntry<int>>(
                            (verse) => DropdownMenuEntry(
                              value: verse.num,
                              label: verse.num.toString(),
                            ),
                          )
                          .toList(),
                      onSelected: (verseNumber) => setState(
                        () => selected = ScriptureRangeRef(
                          bookId: selected.bookId,
                          chapter: selected.chapter,
                          startVerse: verseNumber ?? 1,
                          endVerse: selected.endVerse,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('End Verse'),
                      initialSelection: selected.endVerse,
                      dropdownMenuEntries: (bibleService.getVerses(
                            selected.bookId,
                            selected.chapter,
                          ))
                          .where((v) => v.num >= selected.startVerse)
                          .map<DropdownMenuEntry<int>>(
                            (verse) => DropdownMenuEntry(
                              value: verse.num,
                              label: verse.num.toString(),
                            ),
                          )
                          .toList(),
                      onSelected: (verseNumber) => setState(
                        () => selected = ScriptureRangeRef(
                          bookId: selected.bookId,
                          chapter: selected.chapter,
                          startVerse: selected.startVerse,
                          endVerse: verseNumber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Select'),
          onPressed: () => Navigator.of(context).pop(selected),
        ),
      ],
    );
  }
}
