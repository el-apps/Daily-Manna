import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PassageConfirmationPage extends StatefulWidget {
  final PassageRecognitionResult recognitionResult;
  final String transcribedText;
  final Function(ScriptureRef?) onConfirm;

  const PassageConfirmationPage({
    super.key,
    required this.recognitionResult,
    required this.transcribedText,
    required this.onConfirm,
  });

  @override
  State<PassageConfirmationPage> createState() =>
      _PassageConfirmationPageState();
}

// Keep old dialog name for backwards compatibility
typedef PassageConfirmationDialog = PassageConfirmationPage;

class _PassageConfirmationPageState extends State<PassageConfirmationPage> {
  late PassageRangeRef _selectedRef;

  @override
  void initState() {
    super.initState();
    final result = widget.recognitionResult;
    final bibleService = context.read<BibleService>();

    debugPrint('[PassageConfirmation] Initializing with result: '
        'book=${result.book}, chapter=${result.startChapter}, verse=${result.startVerse}');
    debugPrint('[PassageConfirmation] BibleService has ${bibleService.books.length} books');

    // Find book ID from book name
    String bookId = '';
    if (result.book != null && bibleService.books.isNotEmpty) {
      debugPrint('[PassageConfirmation] Looking for book: ${result.book}');
      final book = bibleService.books.firstWhere(
        (b) {
          final matches = b.title.toLowerCase() == result.book!.toLowerCase();
          if (matches) {
            debugPrint('[PassageConfirmation] Found matching book: ${b.title} (${b.id})');
          }
          return matches;
        },
        orElse: () {
          debugPrint('[PassageConfirmation] No exact match found, using first book: ${bibleService.books.first.title}');
          return bibleService.books.first;
        },
      );
      bookId = book.id;
      debugPrint('[PassageConfirmation] Selected bookId: $bookId');
    } else {
      debugPrint('[PassageConfirmation] Result.book is null or no books available');
    }

    _selectedRef = PassageRangeRef(
      bookId: bookId,
      startChapter: result.startChapter ?? 1,
      startVerse: result.startVerse ?? 1,
      endChapter: result.endChapter,
      endVerse: result.endVerse,
    );
    debugPrint('[PassageConfirmation] Created PassageRangeRef: ${_selectedRef.display}');
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

    Navigator.of(context).pop();
    widget.onConfirm(ref);
  }

  void _cancel() {
    Navigator.of(context).pop();
    widget.onConfirm(null);
  }

  @override
  Widget build(BuildContext context) {
    final recognizedPassage = widget.recognitionResult.book != null
        ? '${widget.recognitionResult.book} ${widget.recognitionResult.startChapter}:${widget.recognitionResult.startVerse}'
        : 'Could not recognize passage';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Passage'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recognized:',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recognizedPassage,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Edit if needed:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            PassageRangeSelector(
              ref: _selectedRef,
              onSelected: (ref) {
                setState(() => _selectedRef = ref);
              },
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
