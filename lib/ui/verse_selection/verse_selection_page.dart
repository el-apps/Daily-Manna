import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/recents_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-screen verse selection page with tabs for Books, Needs Review, and Recents.
class VerseSelectionPage extends StatelessWidget {
  const VerseSelectionPage({
    super.key,
    this.rangeMode = false,
    this.initialBookId,
    this.initialChapter,
    this.initialTabIndex = 0,
  });

  final bool rangeMode;
  final String? initialBookId;
  final int? initialChapter;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: initialTabIndex,
    length: 3,
    child: AppScaffold(
      title: rangeMode ? 'Select Passage' : 'Select Verse',
      showShareButton: false,
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Books'),
          Tab(text: 'Review'),
          Tab(text: 'Recents'),
        ],
      ),
      body: rangeMode
          ? _buildRangeModeBody(context)
          : _buildNormalBody(context),
    ),
  );

  Widget _buildRangeModeBody(BuildContext context) => TabBarView(
    children: [
      BooksTab.range(
        initialBookId: initialBookId,
        initialChapter: initialChapter,
        onRangeSelected: (ref) => context.pop(ref),
      ),
      ReviewTab(onVerseSelected: (ref) => _selectSingleVerse(context, ref)),
      RecentsTab(onVerseSelected: (ref) => _selectSingleVerse(context, ref)),
    ],
  );

  Widget _buildNormalBody(BuildContext context) => TabBarView(
    children: [
      BooksTab(
        initialBookId: initialBookId,
        initialChapter: initialChapter,
        onVerseSelected: (ref) => _selectVerse(context, ref),
      ),
      ReviewTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
      RecentsTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
    ],
  );

  void _selectVerse(BuildContext context, ScriptureRef ref) {
    context.pop(ref);
  }

  void _selectSingleVerse(BuildContext context, ScriptureRef ref) {
    context.pop(
      ScriptureRangeRef(
        bookId: ref.bookId!,
        chapter: ref.chapterNumber!,
        startVerse: ref.verseNumber!,
      ),
    );
  }
}
