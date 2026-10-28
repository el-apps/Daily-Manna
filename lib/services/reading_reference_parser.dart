import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/services/bible_service.dart';

typedef ReadingPassage = ({
  String bookId,
  int startChapter,
  int startVerse,
  int endChapter,
  int endVerse,
});

/// Parses human-entered references without doing I/O.
class ReadingReferenceParser {
  ReadingReferenceParser(this.bible);

  final BibleService bible;

  static final _reference = RegExp(
    r'^(?:((?:(?:[1-3]|iii|ii|i)\s*)?[a-z][a-z .]*?)\s*)?'
    r'(\d+)\s*(?::\s*(\d+))?'
    r'(?:\s*[-–—]\s*(\d+)\s*(?::\s*(\d+))?)?$',
    caseSensitive: false,
  );

  static const _aliases = {
    'gen': ['gn', 'gns'],
    'exod': ['ex', 'exo'],
    'deut': ['dt', 'deu'],
    'ps': ['psalm', 'psa', 'psm'],
    'song': ['sos', 'song of songs', 'songs'],
    'john': ['jn', 'jhn'],
    'rom': ['rm', 'rms'],
    '1john': ['1jn', '1jhn'],
    '2john': ['2jn', '2jhn'],
    '3john': ['3jn', '3jhn'],
    'phil': ['php', 'phlp'],
    'phlm': ['phm'],
    'jas': ['jm', 'jms'],
    'mark': ['mk', 'mrk'],
    'matt': ['mt'],
    'luke': ['lk', 'luk'],
    'rev': ['re', 'rv', 'revelations'],
  };

  List<ReadingPassage> parse(String input, {bool includeAlternatives = false}) {
    if (input.trim().isEmpty) return [];
    if (RegExp(r'^[;,]|[;,\n]\s*[;,\n]|[;,]$').hasMatch(input.trim())) {
      throw const FormatException('Finish each reference between separators.');
    }
    var currentBooks = <Book>[];
    int? verseChapter;
    final passages = <ReadingPassage>[];
    // Keep delimiters: semicolons/newlines begin a new chapter-level reference,
    // while commas inherit verse context (John 3:16,18).
    for (final token in input.split(RegExp(r'(?=[;,\n])|(?<=[;,\n])'))) {
      if (token == ',') continue;
      if (token == ';' || token == '\n') {
        verseChapter = null;
        continue;
      }
      final match = _reference.firstMatch(token.trim());
      if (match == null) {
        throw FormatException(
          'Check “${token.trim()}”. Try John 1,3 or John 3:16–4:12.',
        );
      }
      final bookText = match[1];
      final books = bookText == null ? currentBooks : _findBooks(bookText);
      if (books.isEmpty) {
        throw const FormatException(
          'Start with a book name, such as John 1,3.',
        );
      }
      final inheritVerse =
          bookText == null && match[3] == null && verseChapter != null;
      final chapter = inheritVerse ? verseChapter : int.parse(match[2]!);
      final verse = inheritVerse
          ? int.parse(match[2]!)
          : int.tryParse(match[3] ?? '');
      var endChapter = chapter;
      int? endVerse = verse;
      if (match[4] != null) {
        if (verse != null && match[5] == null) {
          endVerse = int.parse(match[4]!);
        } else {
          endChapter = int.parse(match[4]!);
          endVerse = int.tryParse(match[5] ?? '');
        }
      }
      final validBooks = <Book>[];
      FormatException? error;
      for (final book in includeAlternatives ? books : books.take(1)) {
        try {
          final passage = _parsePassage(
            book,
            chapter,
            verse,
            endChapter,
            endVerse,
          );
          if (!passages.contains(passage)) passages.add(passage);
          validBooks.add(book);
        } on FormatException catch (exception) {
          error = exception;
        }
      }
      if (validBooks.isEmpty) throw error!;
      currentBooks = validBooks;
      verseChapter = verse == null ? null : endChapter;
    }
    return passages;
  }

  ReadingPassage _parsePassage(
    Book book,
    int chapter,
    int? verse,
    int endChapter,
    int? endVerse,
  ) {
    final startLimit = _verseCount(book, chapter);
    final endLimit = _verseCount(book, endChapter);
    final start = verse ?? 1;
    final end = endVerse ?? endLimit;
    if (start < 1 || start > startLimit) {
      throw FormatException('${book.title} $chapter has $startLimit verses.');
    }
    if (end < 1 || end > endLimit) {
      throw FormatException('${book.title} $endChapter has $endLimit verses.');
    }
    if (endChapter < chapter || (endChapter == chapter && end < start)) {
      throw const FormatException(
        'The end of a passage must not precede its start.',
      );
    }
    return (
      bookId: book.id,
      startChapter: chapter,
      startVerse: start,
      endChapter: endChapter,
      endVerse: end,
    );
  }

  int _verseCount(Book book, int chapter) {
    if (chapter < 1 || chapter > book.chapters.length) {
      throw FormatException(
        '${book.title} has ${book.chapters.length} chapters.',
      );
    }
    return book.chapters[chapter - 1].verses.length;
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceFirstMapped(
        RegExp(r'^\s*(iii|ii|i)\s+'),
        (m) => '${m[1]!.length}',
      )
      .replaceAll(RegExp(r'[\s.]'), '');

  List<Book> _findBooks(String text) {
    final query = _normalize(text);
    List<String> names(Book book) => [
      book.id,
      book.title,
      ...?_aliases[book.id.toLowerCase()],
    ].map(_normalize).toList();
    final exact = bible.books
        .where((book) => names(book).contains(query))
        .toList();
    if (exact.isNotEmpty) return exact;
    final prefixes = bible.books
        .where((book) => names(book).any((name) => name.startsWith(query)))
        .toList();
    if (prefixes.isNotEmpty) return prefixes;
    throw FormatException('Book “$text” not recognized. Try a longer name.');
  }
}
