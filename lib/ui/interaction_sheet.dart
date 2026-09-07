import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/ui/study/record_study_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows a bottom sheet for choosing how to interact with a selected passage.
void showInteractionSheet(BuildContext context, ScriptureRef ref) {
  final bibleService = context.read<BibleService>();
  _showInteractionSheet(
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

void showPassageInteractionSheet(
  BuildContext context,
  ScriptureRangeRef passage,
) {
  final bibleService = context.read<BibleService>();
  _showInteractionSheet(
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

void _showInteractionSheet(
  BuildContext context, {
  required String title,
  required ScriptureRef memorizeRef,
  required ScriptureRangeRef initialPassage,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 24,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InteractionButton(
                  icon: Icons.psychology,
                  label: 'Memorize',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            VerseMemorization(initialRef: memorizeRef),
                      ),
                    );
                  },
                ),
                _InteractionButton(
                  icon: Icons.mic,
                  label: 'Recite',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecitationMode()),
                    );
                  },
                ),
                _InteractionButton(
                  icon: Icons.menu_book,
                  label: 'Study',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          RecordStudySheet(initialPassage: initialPassage),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InteractionButton extends StatelessWidget {
  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Theme.of(context).colorScheme.onPrimary;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: const Size(96, 96),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 30),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foregroundColor),
          ),
        ],
      ),
    );
  }
}
