import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/reference_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:daily_manna/ui/verse_selection/suggestions_tab.dart';
import 'package:flutter/material.dart';

Future<ScriptureRangeRef?> showPassageSelector(BuildContext context) =>
    showModalBottomSheet<ScriptureRangeRef>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: MediaQuery.removeViewInsets(
          context: sheetContext,
          removeBottom: true,
          child: const VerseSelectionPage(rangeMode: true),
        ),
      ),
    );

/// Shared reference entry and passage browsing with tap-to-select results.
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

class _VerseSelectionPageState extends State<VerseSelectionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late int _tabIndex;
  String? _bookTitle;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialBookId != null ? 1 : widget.initialTabIndex;
    _tabs = TabController(length: 4, initialIndex: _tabIndex, vsync: this)
      ..addListener(_tabChanged);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.index == _tabIndex) return;
    FocusScope.of(context).unfocus();
    setState(() => _tabIndex = _tabs.index);
  }

  void _browseTitleChanged(String title) {
    setState(() => _bookTitle = title);
  }

  void _select(ScriptureRangeRef ref) {
    FocusScope.of(context).unfocus();
    Navigator.of(context, rootNavigator: true).pop(
      widget.rangeMode
          ? ref
          : ScriptureRef(
              bookId: ref.bookId,
              chapterNumber: ref.chapter,
              verseNumber: ref.startVerse,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.rangeMode ? 'Select Passage' : 'Select Verse';
    return AppScaffold(
      title: _tabIndex == 1 ? (_bookTitle ?? title) : title,
      showShareButton: false,
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Search'),
          Tab(text: 'Books'),
          Tab(text: 'Review'),
          Tab(text: 'Suggestions'),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ReferenceTab(rangeMode: widget.rangeMode, onSelected: _select),
          if (widget.rangeMode)
            BooksTab.range(
              initialBookId: widget.initialBookId,
              initialChapter: widget.initialChapter,
              onSelectionChanged: _browseTitleChanged,
              onRangeSelected: _select,
            )
          else
            BooksTab(
              initialBookId: widget.initialBookId,
              initialChapter: widget.initialChapter,
              onSelectionChanged: _browseTitleChanged,
              onVerseSelected: (ref) => _select(
                ScriptureRangeRef(
                  bookId: ref.bookId!,
                  chapter: ref.chapterNumber!,
                  startVerse: ref.verseNumber!,
                ),
              ),
            ),
          ReviewTab(onPassageSelected: _select),
          SuggestionsTab(onPassageSelected: _select),
        ],
      ),
    );
  }
}
