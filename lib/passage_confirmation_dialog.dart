import 'package:daily_manna/openrouter_service.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter/material.dart';

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
  late TextEditingController _bookController;
  late TextEditingController _startChapterController;
  late TextEditingController _startVerseController;
  late TextEditingController _endChapterController;
  late TextEditingController _endVerseController;

  @override
  void initState() {
    super.initState();
    final result = widget.recognitionResult;
    _bookController = TextEditingController(text: result.book ?? '');
    _startChapterController =
        TextEditingController(text: result.startChapter?.toString() ?? '');
    _startVerseController =
        TextEditingController(text: result.startVerse?.toString() ?? '');
    _endChapterController =
        TextEditingController(text: result.endChapter?.toString() ?? '');
    _endVerseController =
        TextEditingController(text: result.endVerse?.toString() ?? '');
  }

  @override
  void dispose() {
    _bookController.dispose();
    _startChapterController.dispose();
    _startVerseController.dispose();
    _endChapterController.dispose();
    _endVerseController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_bookController.text.isEmpty ||
        _startChapterController.text.isEmpty ||
        _startVerseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      final ref = ScriptureRef(
        bookId: _bookController.text,
        chapterNumber: int.parse(_startChapterController.text),
        verseNumber: int.parse(_startVerseController.text),
      );

      widget.onConfirm(ref);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Passage'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recognized Passage:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            if (widget.recognitionResult.book == null)
              const Text('Could not recognize passage. Please enter manually.')
            else
              Text(
                '${widget.recognitionResult.book} ${widget.recognitionResult.startChapter}:${widget.recognitionResult.startVerse}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 24),
            Text(
              'Edit if needed:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bookController,
              decoration: const InputDecoration(
                labelText: 'Book',
                hintText: 'Genesis, Exodus, etc.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startChapterController,
                    decoration: const InputDecoration(
                      labelText: 'Start Chapter',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _startVerseController,
                    decoration: const InputDecoration(
                      labelText: 'Start Verse',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _endChapterController,
                    decoration: const InputDecoration(
                      labelText: 'End Chapter (optional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endVerseController,
                    decoration: const InputDecoration(
                      labelText: 'End Verse (optional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
