import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/reference_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:daily_manna/ui/verse_selection/suggestions_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// Shared passage selection with one confirmation action for every tab.
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
  final _selections = List<ScriptureRangeRef?>.filled(4, null);

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

  void _choose(int tab, ScriptureRangeRef? ref) {
    setState(() {
      _selections[tab] = !widget.rangeMode && ref != null
          ? ref.copyWith(endVerse: null)
          : ref;
    });
  }

  void _browseTitleChanged(String title) {
    setState(() {
      _bookTitle = title;
      _selections[1] = null;
    });
  }

  void _confirm() {
    final ref = _selections[_tabIndex];
    if (ref == null) return;
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
    final bible = context.read<BibleService>();
    final selected = _selections[_tabIndex];
    final title = widget.rangeMode ? 'Select Passage' : 'Select Verse';
    return AppScaffold(
      title: _tabIndex == 1 ? (_bookTitle ?? title) : title,
      showShareButton: false,
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Reference'),
          Tab(text: 'Books'),
          Tab(text: 'Review'),
          Tab(text: 'Suggestions'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ReferenceTab(
                  rangeMode: widget.rangeMode,
                  onChanged: (ref) => _choose(0, ref),
                ),
                if (widget.rangeMode)
                  BooksTab.range(
                    initialBookId: widget.initialBookId,
                    initialChapter: widget.initialChapter,
                    onSelectionChanged: _browseTitleChanged,
                    onRangeSelected: (ref) => _choose(1, ref),
                  )
                else
                  BooksTab(
                    initialBookId: widget.initialBookId,
                    initialChapter: widget.initialChapter,
                    onSelectionChanged: _browseTitleChanged,
                    onVerseSelected: (ref) => _choose(
                      1,
                      ScriptureRangeRef(
                        bookId: ref.bookId!,
                        chapter: ref.chapterNumber!,
                        startVerse: ref.verseNumber!,
                      ),
                    ),
                  ),
                ReviewTab(onPassageSelected: (ref) => _choose(2, ref)),
                SuggestionsTab(onPassageSelected: (ref) => _choose(3, ref)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected != null) ...[
                    Text(bible.getRangeRefName(selected)),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: selected == null ? null : _confirm,
                      child: Text(
                        widget.rangeMode ? 'Select passage' : 'Select verse',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
