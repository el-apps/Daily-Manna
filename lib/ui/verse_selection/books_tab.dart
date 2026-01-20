import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Browse tab with drill-down navigation: Books → Chapters → Verses.
class BooksTab extends StatefulWidget {
  final void Function(ScriptureRef) onVerseSelected;

  const BooksTab({super.key, required this.onVerseSelected});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  String? _selectedBookId;
  String? _selectedBookTitle;
  int? _selectedChapter;

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
        Expanded(
          child: _buildContent(bibleService),
        ),
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

    return _VersesList(
      verses: bibleService.getVerses(_selectedBookId!, _selectedChapter!),
      onVerseSelected: (verse) => widget.onVerseSelected(
        ScriptureRef(
          bookId: _selectedBookId,
          chapterNumber: _selectedChapter,
          verseNumber: verse,
        ),
      ),
    );
  }

  void _goToBooks() => setState(() {
        _selectedBookId = null;
        _selectedBookTitle = null;
        _selectedChapter = null;
      });

  void _goToChapters() => setState(() {
        _selectedChapter = null;
      });
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
            child: Icon(Icons.arrow_back, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          if (chapter == null)
            Text(bookTitle, style: theme.textTheme.titleMedium)
          else ..._buildChapterBreadcrumb(linkStyle, theme),
        ],
      ),
    );
  }

  List<Widget> _buildChapterBreadcrumb(TextStyle linkStyle, ThemeData theme) => [
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
  'Gen': _BookCategory.law,
  'Exod': _BookCategory.law,
  'Lev': _BookCategory.law,
  'Num': _BookCategory.law,
  'Deut': _BookCategory.law,
  // History (OT)
  'Josh': _BookCategory.history,
  'Judg': _BookCategory.history,
  'Ruth': _BookCategory.history,
  '1Sam': _BookCategory.history,
  '2Sam': _BookCategory.history,
  '1Kgs': _BookCategory.history,
  '2Kgs': _BookCategory.history,
  '1Chr': _BookCategory.history,
  '2Chr': _BookCategory.history,
  'Ezra': _BookCategory.history,
  'Neh': _BookCategory.history,
  'Esth': _BookCategory.history,
  // Poetry
  'Job': _BookCategory.poetry,
  'Ps': _BookCategory.poetry,
  'Prov': _BookCategory.poetry,
  'Eccl': _BookCategory.poetry,
  'Song': _BookCategory.poetry,
  // Major Prophets
  'Isa': _BookCategory.majorProphets,
  'Jer': _BookCategory.majorProphets,
  'Lam': _BookCategory.majorProphets,
  'Ezek': _BookCategory.majorProphets,
  'Dan': _BookCategory.majorProphets,
  // Minor Prophets
  'Hos': _BookCategory.minorProphets,
  'Joel': _BookCategory.minorProphets,
  'Amos': _BookCategory.minorProphets,
  'Obad': _BookCategory.minorProphets,
  'Jonah': _BookCategory.minorProphets,
  'Mic': _BookCategory.minorProphets,
  'Nah': _BookCategory.minorProphets,
  'Hab': _BookCategory.minorProphets,
  'Zeph': _BookCategory.minorProphets,
  'Hag': _BookCategory.minorProphets,
  'Zech': _BookCategory.minorProphets,
  'Mal': _BookCategory.minorProphets,
  // Gospels
  'Matt': _BookCategory.gospels,
  'Mark': _BookCategory.gospels,
  'Luke': _BookCategory.gospels,
  'John': _BookCategory.gospels,
  // Acts
  'Acts': _BookCategory.acts,
  // Pauline Epistles
  'Rom': _BookCategory.paulineEpistles,
  '1Cor': _BookCategory.paulineEpistles,
  '2Cor': _BookCategory.paulineEpistles,
  'Gal': _BookCategory.paulineEpistles,
  'Eph': _BookCategory.paulineEpistles,
  'Phil': _BookCategory.paulineEpistles,
  'Col': _BookCategory.paulineEpistles,
  '1Thess': _BookCategory.paulineEpistles,
  '2Thess': _BookCategory.paulineEpistles,
  '1Tim': _BookCategory.paulineEpistles,
  '2Tim': _BookCategory.paulineEpistles,
  'Titus': _BookCategory.paulineEpistles,
  'Phlm': _BookCategory.paulineEpistles,
  // General Epistles
  'Heb': _BookCategory.generalEpistles,
  'Jas': _BookCategory.generalEpistles,
  '1Pet': _BookCategory.generalEpistles,
  '2Pet': _BookCategory.generalEpistles,
  '1John': _BookCategory.generalEpistles,
  '2John': _BookCategory.generalEpistles,
  '3John': _BookCategory.generalEpistles,
  'Jude': _BookCategory.generalEpistles,
  // Prophecy
  'Rev': _BookCategory.prophecy,
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
              '${category.label} (${books.length})',
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

  const _ChaptersList({required this.chapters, required this.onChapterSelected});

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
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
          crossAxisCount: 5,
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
