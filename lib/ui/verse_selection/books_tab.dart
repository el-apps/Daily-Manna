import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const int _gridCrossAxisCount = 5;

/// Browse tab with drill-down navigation: Books → Chapters → Verses.
class BooksTab extends StatefulWidget {
  final void Function(ScriptureRef)? onVerseSelected;
  final void Function(ScriptureRangeRef)? onRangeSelected;

  const BooksTab({super.key, required this.onVerseSelected}) : onRangeSelected = null;

  const BooksTab.range({super.key, required this.onRangeSelected})
      : onVerseSelected = null;

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
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();

    // Only show breadcrumbs when navigated into a book
    if (_selectedBookId == null) {
      return _buildContent(bibleService);
    }

    return Column(
      children: [
        _Breadcrumbs(
          bookTitle: _selectedBookTitle!,
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
    if (_selectedBookId == null) {
      return _BooksList(
        books: bibleService.books,
        onBookSelected: (book) => setState(() {
          _selectedBookId = book.id;
          _selectedBookTitle = book.title;
        }),
      );
    }

    if (_selectedChapter == null) {
      return _ChaptersList(
        chapters: bibleService.getChapters(_selectedBookId!),
        onChapterSelected: (chapter) => setState(() {
          _selectedChapter = chapter;
        }),
      );
    }

    final verses = bibleService.getVerses(_selectedBookId!, _selectedChapter!);

    if (_startVerse != null) {
      return _VersesListRangeEnd(
        verses: verses,
        startVerse: _startVerse!,
        onEndVerseSelected: _selectEndVerse,
      );
    }

    return _VersesList(
      verses: verses,
      onVerseSelected: _handleVerseSelected,
    );
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

  void _goToBooks() => setState(() {
    _selectedBookId = null;
    _selectedBookTitle = null;
    _selectedChapter = null;
    _startVerse = null;
  });

  void _goToChapters() => setState(() {
    _selectedChapter = null;
    _startVerse = null;
  });
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

/// Book categories for organized display.
enum _BookCategory {
  law('Law'),
  history('History'),
  poetry('Poetry'),
  majorProphets('Major Prophets'),
  minorProphets('Minor Prophets'),
  gospels('Gospels'),
  acts('History'),
  paulineEpistles('Pauline Epistles'),
  generalEpistles('General Epistles'),
  prophecy('Prophecy');

  final String label;
  const _BookCategory(this.label);
}

const _bookCategories = <String, _BookCategory>{
  // Law
  'gen': _BookCategory.law,
  'exod': _BookCategory.law,
  'lev': _BookCategory.law,
  'num': _BookCategory.law,
  'deut': _BookCategory.law,
  // History (OT)
  'josh': _BookCategory.history,
  'judg': _BookCategory.history,
  'ruth': _BookCategory.history,
  '1sam': _BookCategory.history,
  '2sam': _BookCategory.history,
  '1kgs': _BookCategory.history,
  '2kgs': _BookCategory.history,
  '1chr': _BookCategory.history,
  '2chr': _BookCategory.history,
  'ezra': _BookCategory.history,
  'neh': _BookCategory.history,
  'esth': _BookCategory.history,
  // Poetry
  'job': _BookCategory.poetry,
  'ps': _BookCategory.poetry,
  'prov': _BookCategory.poetry,
  'eccl': _BookCategory.poetry,
  'song': _BookCategory.poetry,
  // Major Prophets
  'isa': _BookCategory.majorProphets,
  'jer': _BookCategory.majorProphets,
  'lam': _BookCategory.majorProphets,
  'ezek': _BookCategory.majorProphets,
  'dan': _BookCategory.majorProphets,
  // Minor Prophets
  'hos': _BookCategory.minorProphets,
  'joel': _BookCategory.minorProphets,
  'amos': _BookCategory.minorProphets,
  'obad': _BookCategory.minorProphets,
  'jonah': _BookCategory.minorProphets,
  'mic': _BookCategory.minorProphets,
  'nah': _BookCategory.minorProphets,
  'hab': _BookCategory.minorProphets,
  'zeph': _BookCategory.minorProphets,
  'hag': _BookCategory.minorProphets,
  'zech': _BookCategory.minorProphets,
  'mal': _BookCategory.minorProphets,
  // Gospels
  'matt': _BookCategory.gospels,
  'mark': _BookCategory.gospels,
  'luke': _BookCategory.gospels,
  'john': _BookCategory.gospels,
  // Acts
  'acts': _BookCategory.acts,
  // Pauline Epistles
  'rom': _BookCategory.paulineEpistles,
  '1cor': _BookCategory.paulineEpistles,
  '2cor': _BookCategory.paulineEpistles,
  'gal': _BookCategory.paulineEpistles,
  'eph': _BookCategory.paulineEpistles,
  'phil': _BookCategory.paulineEpistles,
  'col': _BookCategory.paulineEpistles,
  '1thess': _BookCategory.paulineEpistles,
  '2thess': _BookCategory.paulineEpistles,
  '1tim': _BookCategory.paulineEpistles,
  '2tim': _BookCategory.paulineEpistles,
  'titus': _BookCategory.paulineEpistles,
  'phlm': _BookCategory.paulineEpistles,
  // General Epistles
  'heb': _BookCategory.generalEpistles,
  'jas': _BookCategory.generalEpistles,
  '1pet': _BookCategory.generalEpistles,
  '2pet': _BookCategory.generalEpistles,
  '1john': _BookCategory.generalEpistles,
  '2john': _BookCategory.generalEpistles,
  '3john': _BookCategory.generalEpistles,
  'jude': _BookCategory.generalEpistles,
  // Prophecy
  'rev': _BookCategory.prophecy,
};

class _BooksList extends StatefulWidget {
  final List<Book> books;
  final void Function(Book) onBookSelected;

  const _BooksList({required this.books, required this.onBookSelected});

  @override
  State<_BooksList> createState() => _BooksListState();
}

class _BooksListState extends State<_BooksList> {
  final Set<_BookCategory> _expandedCategories = {};

  @override
  Widget build(BuildContext context) {
    // Group books by category
    final grouped = <_BookCategory, List<Book>>{};
    for (final book in widget.books) {
      final category = _bookCategories[book.id];
      if (category != null) {
        grouped.putIfAbsent(category, () => []).add(book);
      }
    }

    return ListView(
      children: [
        for (final category in _BookCategory.values)
          if (grouped.containsKey(category))
            _CategorySection(
              category: category,
              books: grouped[category]!,
              isExpanded: _expandedCategories.contains(category),
              onToggle: () => setState(() {
                if (_expandedCategories.contains(category)) {
                  _expandedCategories.remove(category);
                } else {
                  _expandedCategories.add(category);
                }
              }),
              onBookSelected: widget.onBookSelected,
            ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _BookCategory category;
  final List<Book> books;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(Book) onBookSelected;

  const _CategorySection({
    required this.category,
    required this.books,
    required this.isExpanded,
    required this.onToggle,
    required this.onBookSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        title: Text(
          category.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
        onTap: onToggle,
      ),
      if (isExpanded)
        ...books.map(
          (book) => ListTile(
            title: Text(book.title),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            onTap: () => onBookSelected(book),
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
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
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
