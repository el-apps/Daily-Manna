import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/ui/study/study_log_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows a dialog for choosing how to engage with a selected passage.
void showPracticeModeDialog(BuildContext context, ScriptureRef ref) {
  final bibleService = context.read<BibleService>();
  _showEngagementDialog(
    context,
    title: bibleService.getRefName(ref),
    memorizeRef: ref,
    initialPassage: ScriptureRangeRef(
      bookId: ref.bookId!,
      chapter: ref.chapterNumber!,
      startVerse: ref.verseNumber!,
    ),
  );
}

void showPassageEngagementDialog(
  BuildContext context,
  ScriptureRangeRef passage,
) {
  final bibleService = context.read<BibleService>();
  _showEngagementDialog(
    context,
    title: bibleService.getRangeRefName(passage),
    memorizeRef: ScriptureRef(
      bookId: passage.bookId,
      chapterNumber: passage.chapter,
      verseNumber: passage.startVerse,
    ),
    initialPassage: passage,
  );
}

void _showEngagementDialog(
  BuildContext context, {
  required String title,
  required ScriptureRef memorizeRef,
  required ScriptureRangeRef initialPassage,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const Text('How would you like to engage?'),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VerseMemorization(initialRef: memorizeRef),
              ),
            );
          },
          child: const Text('Memorize'),
        ),
        FilledButton.tonal(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RecitationMode()));
          },
          child: const Text('Recite'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            showDialog<void>(
              context: context,
              builder: (_) => StudyLogDialog(initialPassage: initialPassage),
            );
          },
          child: const Text('Study'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
