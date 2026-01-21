import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/recents_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:flutter/material.dart';

/// Full-screen verse selection page with tabs for Books, Needs Review, and Recents.
class VerseSelectionPage extends StatelessWidget {
  const VerseSelectionPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: AppScaffold(
      title: 'Select Verse',
      showShareButton: false,
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Books'),
          Tab(text: 'Review'),
          Tab(text: 'Recents'),
        ],
      ),
      body: TabBarView(
        children: [
          BooksTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
          ReviewTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
          RecentsTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
        ],
      ),
    ),
  );

  void _selectVerse(BuildContext context, ScriptureRef ref) {
    Navigator.of(context).pop(ref);
  }
}
