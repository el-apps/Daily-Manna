import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerseSelector extends StatelessWidget {
  const VerseSelector({super.key, required this.ref, required this.onSelected});

  // TODO(#15): include a way for the user to easily select from their queued
  //            verses. This should be configurable a parameter to the widget
  final ScriptureRef ref;
  final Function(ScriptureRef) onSelected;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    return ListTile(
      title: Text(ref.complete ? bibleService.getRefName(ref) : 'Select verse'),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _openSelectorDialog(context),
    );
  }

  void _openSelectorDialog(BuildContext context) async {
    final selectedRef = await showDialog<ScriptureRef>(
      context: context,
      builder: (context) => SelectVerseDialog(ref: ref),
    );

    if (selectedRef != null) {
      onSelected(selectedRef);
    }
  }
}

class SelectVerseDialog extends StatefulWidget {
  const SelectVerseDialog({super.key, required this.ref});

  final ScriptureRef ref;

  @override
  State<SelectVerseDialog> createState() => _SelectVerseDialogState();
}

class _SelectVerseDialogState extends State<SelectVerseDialog> {
  late ScriptureRef selected;

  @override
  void initState() {
    super.initState();
    selected = widget.ref;
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    return AlertDialog(
      title: const Text('Select Verse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          DropdownMenu(
            width: double.infinity,
            initialSelection: selected.bookId,
            dropdownMenuEntries: bibleService.books
                .map<DropdownMenuEntry<String>>(
                  (book) =>
                      DropdownMenuEntry(value: book.id, label: book.title),
                )
                .toList(),
            onSelected: (bookId) => setState(
              () => (selected = selected.copyWith(
                bookId: bookId,
                chapterNumber: selected.chapterNumber ?? 1,
                verseNumber: selected.verseNumber ?? 1,
              )),
            ),
          ),
          if (selected.bookId != null)
            Row(
              spacing: 8,
              children: [
                if (selected.bookId != null)
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      initialSelection: selected.chapterNumber,
                      dropdownMenuEntries:
                          (bibleService.getChapters(selected.bookId!))
                              .map<DropdownMenuEntry<int>>(
                                (chapter) => DropdownMenuEntry(
                                  value: chapter.num,
                                  label: chapter.num.toString(),
                                ),
                              )
                              .toList(),
                      onSelected: (chapterNumber) => setState(
                        () => (selected = selected.copyWith(
                          chapterNumber: chapterNumber,
                          verseNumber: selected.verseNumber ?? 1,
                        )),
                      ),
                    ),
                  ),
                if (selected.chapterNumber != null)
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      initialSelection: selected.verseNumber,
                      dropdownMenuEntries:
                          (bibleService.getVerses(
                                selected.bookId!,
                                selected.chapterNumber!,
                              ))
                              .map<DropdownMenuEntry<int>>(
                                (verse) => DropdownMenuEntry(
                                  value: verse.num,
                                  label: verse.num.toString(),
                                ),
                              )
                              .toList(),
                      onSelected: (verseNumber) => setState(
                        () => (selected = selected.copyWith(
                          verseNumber: verseNumber,
                        )),
                      ),
                    ),
                  ),
              ],
            ),
        ],
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
