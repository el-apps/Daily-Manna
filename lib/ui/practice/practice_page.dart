import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/memorization/verse_selector.dart';
import 'package:daily_manna/ui/practice_mode_dialog.dart';
import 'package:flutter/material.dart';

/// Page for selecting any verse to practice.
class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  ScriptureRef _ref = const ScriptureRef();

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Practice',
    showShareButton: false,
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: VerseSelector(
        ref: _ref,
        onSelected: (ref) {
          setState(() => _ref = ref);
          showPracticeModeDialog(context, ref);
        },
      ),
    ),
  );
}
