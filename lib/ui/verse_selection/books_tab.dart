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

class _BooksList extends StatelessWidget {
  final List<Book> books;
  final void Function(Book) onBookSelected;

  const _BooksList({required this.books, required this.onBookSelected});

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return ListTile(
            title: Text(book.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onBookSelected(book),
          );
        },
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
