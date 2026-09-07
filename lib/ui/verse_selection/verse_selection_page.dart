import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/suggestions_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Full-screen verse selection page with tabs for Books, Needs Review, and Recents.
class VerseSelectionPage extends StatefulWidget {
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
  State<VerseSelectionPage> createState() => _VerseSelectionPageState();
}

class _VerseSelectionPageState extends State<VerseSelectionPage> {
  late String _title = widget.rangeMode ? 'Select Passage' : 'Select Verse';
  bool _hasSelectedBook = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialBookId != null) {
      final book = context.read<BibleService>().books.firstWhere(
        (book) => book.id == widget.initialBookId,
      );
      _title = book.title;
      if (widget.initialChapter != null) {
        _title = '${book.title} ${widget.initialChapter}';
      }
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    initialIndex: widget.initialTabIndex,
    length: 3,
    child: AppScaffold(
      title: _title,
      showShareButton: false,
      bottom: (_hasSelectedBook || widget.initialBookId != null)
          ? null
          : const TabBar(
              tabs: [
                Tab(text: 'Books'),
                Tab(text: 'Review'),
                Tab(text: 'Suggestions'),
              ],
            ),
      body: widget.rangeMode
          ? _buildRangeModeBody(context)
          : _buildNormalBody(context),
    ),
  );

  Widget _buildRangeModeBody(BuildContext context) => TabBarView(
    children: [
      BooksTab.range(
        initialBookId: widget.initialBookId,
        initialChapter: widget.initialChapter,
        onSelectionChanged: _updateTitle,
        onRangeSelected: (ref) => context.pop(ref),
      ),
      ReviewTab(onVerseSelected: (ref) => _selectSingleVerse(context, ref)),
      SuggestionsTab(onPassageSelected: (ref) => context.pop(ref)),
    ],
  );

  Widget _buildNormalBody(BuildContext context) => TabBarView(
    children: [
      BooksTab(
        initialBookId: widget.initialBookId,
        initialChapter: widget.initialChapter,
        onSelectionChanged: _updateTitle,
        onVerseSelected: (ref) => _selectVerse(context, ref),
      ),
      ReviewTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
      SuggestionsTab(
        onPassageSelected: (ref) => _selectVerse(
          context,
          ScriptureRef(
            bookId: ref.bookId,
            chapterNumber: ref.chapter,
            verseNumber: ref.startVerse,
          ),
        ),
      ),
    ],
  );

  void _selectVerse(BuildContext context, ScriptureRef ref) {
    context.pop(ref);
  }

  void _updateTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title;
        _hasSelectedBook = true;
      });
    }
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
