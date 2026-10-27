import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/reference_tab.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/suggestions_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/reading_reference_parser.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<ScriptureRangeRef?> showPassageSelector(
  BuildContext context, {
  bool allowReadingLog = false,
}) => showModalBottomSheet<ScriptureRangeRef>(
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
    child: VerseSelectionPage(
      rangeMode: true,
      allowReadingLog: allowReadingLog,
    ),
  ),
);

/// Shared reference entry and browsing, with optional logging for Interact.
class VerseSelectionPage extends StatefulWidget {
  const VerseSelectionPage({
    super.key,
    this.rangeMode = false,
    this.allowReadingLog = false,
    this.initialBookId,
    this.initialChapter,
    this.initialTabIndex = 0,
  });

  final bool rangeMode;
  // Reference entry is always available; only Interact offers activity logging.
  final bool allowReadingLog;
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
    initialIndex: widget.initialBookId != null ? 1 : widget.initialTabIndex,
    length: 4,
    child: AppScaffold(
      title: _title,
      showShareButton: false,
      bottom: (_hasSelectedBook || widget.initialBookId != null)
          ? null
          : TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Reference'),
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
      ReferenceTab(
        onSelected: (ref) =>
            Navigator.of(context, rootNavigator: true).pop(ref),
        onLogReading: widget.allowReadingLog ? _logReading : null,
      ),
      BooksTab.range(
        initialBookId: widget.initialBookId,
        initialChapter: widget.initialChapter,
        onSelectionChanged: _updateTitle,
        onRangeSelected: (ref) =>
            Navigator.of(context, rootNavigator: true).pop(ref),
      ),
      ReviewTab(
        onPassageSelected: (ref) =>
            Navigator.of(context, rootNavigator: true).pop(ref),
      ),
      SuggestionsTab(
        onPassageSelected: (ref) =>
            Navigator.of(context, rootNavigator: true).pop(ref),
      ),
    ],
  );

  Widget _buildNormalBody(BuildContext context) => TabBarView(
    children: [
      ReferenceTab(
        rangeMode: false,
        onSelected: (ref) => _selectVerse(
          context,
          ScriptureRef(
            bookId: ref.bookId,
            chapterNumber: ref.chapter,
            verseNumber: ref.startVerse,
          ),
        ),
      ),
      BooksTab(
        initialBookId: widget.initialBookId,
        initialChapter: widget.initialChapter,
        onSelectionChanged: _updateTitle,
        onVerseSelected: (ref) => _selectVerse(context, ref),
      ),
      ReviewTab(
        onPassageSelected: (ref) => _selectVerse(
          context,
          ScriptureRef(
            bookId: ref.bookId,
            chapterNumber: ref.chapter,
            verseNumber: ref.startVerse,
          ),
        ),
      ),
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
    Navigator.of(context, rootNavigator: true).pop(ref);
  }

  Future<void> _logReading(List<ReadingPassage> passages) async {
    await context.read<ResultsService>().addReading(passages);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reading logged')));
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _updateTitle(String title) {
    if (mounted) {
      setState(() {
        _title = title;
        _hasSelectedBook = true;
      });
    }
  }
}
