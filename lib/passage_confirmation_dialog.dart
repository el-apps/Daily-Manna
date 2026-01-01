import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PassageConfirmationDialog extends StatefulWidget {
  final PassageRecognitionResult recognitionResult;
  final String transcribedText;
  final Function(ScriptureRef?) onConfirm;

  const PassageConfirmationDialog({
    super.key,
    required this.recognitionResult,
    required this.transcribedText,
    required this.onConfirm,
  });

  @override
  State<PassageConfirmationDialog> createState() =>
      _PassageConfirmationDialogState();
}

class _PassageConfirmationDialogState extends State<PassageConfirmationDialog> {
  late PassageRangeRef _selectedRef;

  @override
  void initState() {
    super.initState();
    final result = widget.recognitionResult;
    final bibleService = context.read<BibleService>();

    // Find book ID from book name
    String bookId = '';
    if (result.book != null) {
      final book = bibleService.books.firstWhere(
        (b) => b.title.toLowerCase() == result.book!.toLowerCase(),
        orElse: () => bibleService.books.first,
      );
      bookId = book.id;
    }

    _selectedRef = PassageRangeRef(
      bookId: bookId,
      startChapter: result.startChapter ?? 1,
      startVerse: result.startVerse ?? 1,
      endChapter: result.endChapter,
      endVerse: result.endVerse,
    );
  }

  void _confirm() {
    if (!_selectedRef.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid passage')),
      );
      return;
    }

    final ref = ScriptureRef(
      bookId: _selectedRef.bookId,
      chapterNumber: _selectedRef.startChapter,
      verseNumber: _selectedRef.startVerse,
    );

    widget.onConfirm(ref);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final recognizedPassage = widget.recognitionResult.book != null
        ? '${widget.recognitionResult.book} ${widget.recognitionResult.startChapter}:${widget.recognitionResult.startVerse}'
        : 'Could not recognize passage';

    return AlertDialog(
      title: const Text('Confirm Passage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recognized:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              recognizedPassage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              'Edit if needed:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            PassageRangeSelector(
              ref: _selectedRef,
              onSelected: (ref) {
                setState(() => _selectedRef = ref);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onConfirm(null);
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
