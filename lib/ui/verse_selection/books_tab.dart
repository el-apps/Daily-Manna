import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const int _gridCrossAxisCount = 5;

/// Browse tab with drill-down navigation: Books → Chapters → Verses.
class BooksTab extends StatefulWidget {
  final void Function(ScriptureRef)? onVerseSelected;
  final void Function(ScriptureRangeRef)? onRangeSelected;
  final String? initialBookId;
  final int? initialChapter;

  const BooksTab({
    super.key,
    required this.onVerseSelected,
    this.initialBookId,
    this.initialChapter,
  }) : onRangeSelected = null;

  const BooksTab.range({
    super.key,
    required this.onRangeSelected,
    this.initialBookId,
    this.initialChapter,
  }) : onVerseSelected = null;

  bool get rangeMode => onRangeSelected != null;

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  String? _selectedBookId;
  String? _selectedBookTitle;
  int? _selectedChapter;
  int? _startVerse; // For range mode: the start verse being selected

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId;
    _selectedChapter = widget.initialChapter;
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final selectedBook = _selectedBookId == null
        ? null
        : bibleService.books.firstWhere((book) => book.id == _selectedBookId);

    // Only show breadcrumbs when navigated into a book
    if (_selectedBookId == null) {
      return _buildContent(bibleService);
    }

    return Column(
      children: [
        _Breadcrumbs(
          bookTitle: _selectedBookTitle ?? selectedBook!.title,
          chapter: _selectedChapter,
          onHomeTap: _goToBooks,
          onBookTap: _goToChapters,
        ),
        if (_startVerse != null)
          _RangeHeader(
            bookTitle: _selectedBookTitle!,
            chapter: _selectedChapter!,
            startVerse: _startVerse!,
            onJustThisVerse: _selectSingleVerseAsRange,
          ),
        Expanded(child: _buildContent(bibleService)),
      ],
    );
  }

  Widget _buildContent(BibleService bibleService) {
    final modeQuery = widget.rangeMode ? '?mode=range' : '';
    if (_selectedBookId == null) {
      return _BooksList(
        books: bibleService.books,
        onBookSelected: (book) {
          context.go('/select/books/${book.id}$modeQuery');
        },
      );
    }

    if (_selectedChapter == null) {
      return _ChaptersList(
        chapters: bibleService.getChapters(_selectedBookId!),
        onChapterSelected: (chapter) {
          context.go('/select/books/$_selectedBookId/$chapter$modeQuery');
        },
      );
    }

    final verses = bibleService.getVerses(_selectedBookId!, _selectedChapter!);

    if (widget.rangeMode && _startVerse == null) {
      return Column(
        children: [
          _ChapterAction(
            onSelect: () => widget.onRangeSelected!(
              ScriptureRangeRef(
                bookId: _selectedBookId!,
                chapter: _selectedChapter!,
                startVerse: verses.first.num,
                endVerse: verses.last.num,
              ),
            ),
          ),
          Expanded(
            child: _VersesList(
              verses: verses,
              onVerseSelected: _handleVerseSelected,
            ),
          ),
        ],
      );
    }

    if (_startVerse != null) {
      return _VersesListRangeEnd(
        verses: verses,
        startVerse: _startVerse!,
        onEndVerseSelected: _selectEndVerse,
      );
    }

    return _VersesList(verses: verses, onVerseSelected: _handleVerseSelected);
  }

  void _handleVerseSelected(int verse) {
    if (widget.rangeMode) {
      setState(() {
        _startVerse = verse;
      });
    } else {
      widget.onVerseSelected!(
        ScriptureRef(
          bookId: _selectedBookId,
          chapterNumber: _selectedChapter,
          verseNumber: verse,
        ),
      );
    }
  }

  void _selectSingleVerseAsRange() {
    widget.onRangeSelected!(
      ScriptureRangeRef(
        bookId: _selectedBookId!,
        chapter: _selectedChapter!,
        startVerse: _startVerse!,
        endVerse: null,
      ),
    );
  }

  void _selectEndVerse(int endVerse) {
    widget.onRangeSelected!(
      ScriptureRangeRef(
        bookId: _selectedBookId!,
        chapter: _selectedChapter!,
        startVerse: _startVerse!,
        endVerse: endVerse,
      ),
    );
  }

  void _goToBooks() =>
      context.go('/select/books${widget.rangeMode ? '?mode=range' : ''}');

  void _goToChapters() => context.go(
    '/select/books/$_selectedBookId${widget.rangeMode ? '?mode=range' : ''}',
  );
}

class _RangeHeader extends StatelessWidget {
  final String bookTitle;
  final int chapter;
  final int startVerse;
  final VoidCallback onJustThisVerse;

  const _RangeHeader({
    required this.bookTitle,
    required this.chapter,
    required this.startVerse,
    required this.onJustThisVerse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$bookTitle $chapter:$startVerse – Select end verse',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onJustThisVerse,
            child: const Text('Just this verse'),
          ),
        ],
      ),
    );
  }
}

class _ChapterAction extends StatelessWidget {
  final VoidCallback onSelect;

  const _ChapterAction({required this.onSelect});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onSelect,
        icon: const Icon(Icons.menu_book),
        label: const Text('Select entire chapter'),
      ),
    ),
  );
}

class _Breadcrumbs extends StatelessWidget {
  final String bookTitle;
  final int? chapter;
  final VoidCallback onHomeTap;
  final VoidCallback onBookTap;

  const _Breadcrumbs({
    required this.bookTitle,
    required this.chapter,
    required this.onHomeTap,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = TextStyle(color: theme.colorScheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: double.infinity,
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          GestureDetector(
            onTap: onHomeTap,
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          if (chapter == null)
            Text(bookTitle, style: theme.textTheme.titleMedium)
          else
            ..._buildChapterBreadcrumb(linkStyle, theme),
        ],
      ),
    );
  }

  List<Widget> _buildChapterBreadcrumb(TextStyle linkStyle, ThemeData theme) =>
      [
        GestureDetector(
          onTap: onBookTap,
          child: Text(bookTitle, style: linkStyle),
        ),
        const _BreadcrumbSeparator(),
        Text('Chapter $chapter', style: theme.textTheme.titleMedium),
      ];
}

class _BreadcrumbSeparator extends StatelessWidget {
  const _BreadcrumbSeparator();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Icon(Icons.chevron_right, size: 16),
  );
}

class _BooksList extends StatefulWidget {
  final List<Book> books;
  final void Function(Book) onBookSelected;

  const _BooksList({required this.books, required this.onBookSelected});

  @override
  State<_BooksList> createState() => _BooksListState();
}

class _BooksListState extends State<_BooksList> {
  @override
  Widget build(BuildContext context) {
    final splitIndex = widget.books.indexWhere((book) => book.id == 'matt');
    final oldTestament = widget.books.sublist(
      0,
      splitIndex == -1 ? widget.books.length : splitIndex,
    );
    final newTestament = splitIndex == -1
        ? <Book>[]
        : widget.books.sublist(splitIndex);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  child: _TestamentColumn(
                    title: 'Old Testament',
                    books: oldTestament,
                    onBookSelected: widget.onBookSelected,
                  ),
                ),
                Expanded(
                  child: _TestamentColumn(
                    title: 'New Testament',
                    books: newTestament,
                    onBookSelected: widget.onBookSelected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TestamentColumn extends StatelessWidget {
  final String title;
  final List<Book> books;
  final void Function(Book) onBookSelected;

  const _TestamentColumn({
    required this.title,
    required this.books,
    required this.onBookSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      ...books.map(
        (book) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            onPressed: () => onBookSelected(book),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ChaptersList extends StatelessWidget {
  final List<Chapter> chapters;
  final void Function(int) onChapterSelected;

  const _ChaptersList({
    required this.chapters,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _gridCrossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: chapters.length,
    itemBuilder: (context, index) {
      final chapter = chapters[index];
      return _NumberButton(
        number: chapter.num,
        onTap: () => onChapterSelected(chapter.num),
      );
    },
  );
}

class _VersesList extends StatelessWidget {
  final List<Verse> verses;
  final void Function(int) onVerseSelected;

  const _VersesList({required this.verses, required this.onVerseSelected});

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _gridCrossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: verses.length,
    itemBuilder: (context, index) {
      final verse = verses[index];
      return _NumberButton(
        number: verse.num,
        onTap: () => onVerseSelected(verse.num),
      );
    },
  );
}

class _VersesListRangeEnd extends StatelessWidget {
  final List<Verse> verses;
  final int startVerse;
  final void Function(int) onEndVerseSelected;

  const _VersesListRangeEnd({
    required this.verses,
    required this.startVerse,
    required this.onEndVerseSelected,
  });

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _gridCrossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: verses.length,
    itemBuilder: (context, index) {
      final verse = verses[index];
      final isSelectable = verse.num >= startVerse;
      final isStartVerse = verse.num == startVerse;
      return _NumberButtonRangeEnd(
        number: verse.num,
        isSelectable: isSelectable,
        isStartVerse: isStartVerse,
        onTap: isSelectable ? () => onEndVerseSelected(verse.num) : null,
      );
    },
  );
}

class _NumberButton extends StatelessWidget {
  final int number;
  final VoidCallback onTap;

  const _NumberButton({required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Center(
        child: Text(
          number.toString(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ),
  );
}

class _NumberButtonRangeEnd extends StatelessWidget {
  final int number;
  final bool isSelectable;
  final bool isStartVerse;
  final VoidCallback? onTap;

  const _NumberButtonRangeEnd({
    required this.number,
    required this.isSelectable,
    required this.isStartVerse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor;
    final Color textColor;

    if (isStartVerse) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (isSelectable) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurface;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            number.toString(),
            style: theme.textTheme.titleMedium?.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
