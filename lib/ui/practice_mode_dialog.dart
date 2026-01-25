import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Shows a dialog for choosing between Recite and Memorize modes.
void showPracticeModeDialog(BuildContext context, ScriptureRef ref) {
  final bibleService = context.read<BibleService>();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(bibleService.getRefName(ref)),
      content: const Text('How would you like to practice?'),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VerseMemorization(initialRef: ref),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}
