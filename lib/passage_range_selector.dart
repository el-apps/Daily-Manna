import 'package:daily_manna/bible_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PassageRangeRef {
  final String bookId;
  final int startChapter;
  final int startVerse;
  final int? endChapter;
  final int? endVerse;

  PassageRangeRef({
    required this.bookId,
    required this.startChapter,
    required this.startVerse,
    this.endChapter,
    this.endVerse,
  });

  bool get complete => bookId.isNotEmpty && startChapter > 0 && startVerse > 0;
}

class PassageRangeSelector extends StatelessWidget {
  final PassageRangeRef ref;
  final Function(PassageRangeRef) onSelected;

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
    final selectedRef = await showDialog<PassageRangeRef>(
      context: context,
      builder: (context) => _SelectPassageRangeDialog(ref: ref),
    );

    if (selectedRef != null) {
      onSelected(selectedRef);
    }
  }
}

class _SelectPassageRangeDialog extends StatefulWidget {
  final PassageRangeRef ref;

  const _SelectPassageRangeDialog({required this.ref});

  @override
  State<_SelectPassageRangeDialog> createState() =>
      _SelectPassageRangeDialogState();
}

class _SelectPassageRangeDialogState extends State<_SelectPassageRangeDialog> {
  late PassageRangeRef selected;

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
              initialSelection: selected.bookId.isNotEmpty ? selected.bookId : null,
              label: const Text('Book'),
              dropdownMenuEntries: bibleService.books
                  .map<DropdownMenuEntry<String>>(
                    (book) =>
                        DropdownMenuEntry(value: book.id, label: book.title),
                  )
                  .toList(),
              onSelected: (bookId) => setState(
                () => selected = PassageRangeRef(
                  bookId: bookId ?? '',
                  startChapter: 1,
                  startVerse: 1,
                ),
              ),
            ),

            // Start verse selector
            if (selected.bookId.isNotEmpty) ...[
              Text(
                'Start Verse',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Chapter'),
                      initialSelection: selected.startChapter,
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
                        () => selected = PassageRangeRef(
                          bookId: selected.bookId,
                          startChapter: chapterNumber ?? 1,
                          startVerse: selected.startVerse,
                          endChapter: selected.endChapter ?? chapterNumber,
                          endVerse: selected.endVerse ?? selected.startVerse,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Verse'),
                      initialSelection: selected.startVerse,
                      dropdownMenuEntries:
                          (bibleService.getVerses(
                                selected.bookId,
                                selected.startChapter,
                              ))
                              .map<DropdownMenuEntry<int>>(
                                (verse) => DropdownMenuEntry(
                                  value: verse.num,
                                  label: verse.num.toString(),
                                ),
                              )
                              .toList(),
                      onSelected: (verseNumber) => setState(
                        () => selected = PassageRangeRef(
                          bookId: selected.bookId,
                          startChapter: selected.startChapter,
                          startVerse: verseNumber ?? 1,
                          endChapter: selected.endChapter ?? selected.startChapter,
                          endVerse: selected.endVerse ?? verseNumber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // End verse selector
            if (selected.bookId.isNotEmpty)
              Text(
                'End Verse',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (selected.bookId.isNotEmpty)
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Chapter'),
                      initialSelection: selected.endChapter,
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
                        () => selected = PassageRangeRef(
                          bookId: selected.bookId,
                          startChapter: selected.startChapter,
                          startVerse: selected.startVerse,
                          endChapter: chapterNumber,
                          endVerse: selected.endVerse ?? 1,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      label: const Text('Verse'),
                      initialSelection: selected.endVerse,
                      dropdownMenuEntries: (selected.endChapter != null
                              ? bibleService.getVerses(
                                  selected.bookId,
                                  selected.endChapter!,
                                )
                              : [])
                          .map<DropdownMenuEntry<int>>(
                            (verse) => DropdownMenuEntry(
                              value: verse.num,
                              label: verse.num.toString(),
                            ),
                          )
                          .toList(),
                      onSelected: (verseNumber) => setState(
                        () => selected = PassageRangeRef(
                          bookId: selected.bookId,
                          startChapter: selected.startChapter,
                          startVerse: selected.startVerse,
                          endChapter: selected.endChapter,
                          endVerse: verseNumber,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
