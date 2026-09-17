import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:flutter/material.dart';

class BibleService {
  BibleService();

  late BibleParser _parser;
  late List<Book> _books;
  late Map<String, Book> _booksMap;
  bool _isLoaded = false;

  /// Builds a service pre-populated from the given books (no XML load).
  /// Used by tests to exercise real lookup/display logic.
  BibleService.fromBooks(Iterable<Book> books) {
    _books = books.toList();
    _booksMap = Map.fromEntries(_books.map((b) => MapEntry(b.id, b)));
    _isLoaded = true;
  }

  get isLoaded => _isLoaded;
  List<Book> get books => _books;
  Map<String, Book> get booksMap => _booksMap;

  Future load(BuildContext context) async {
    final xmlString = await DefaultAssetBundle.of(
      context,
    ).loadString('assets/kjv.xml');
    _parser = BibleParser.fromString(xmlString, format: 'OSIS');
    _books = (await _parser.books.toList())
        .where((b) => b.title != 'Unknown')
        .toList();
    _booksMap = Map.fromEntries(_books.map((b) => MapEntry(b.id, b)));
    _isLoaded = true;
  }

  /// Looks up a book by ID, matching case-insensitively so IDs returned by
  /// external recognition (e.g. "Psa", "1Cor") resolve to the app's
  /// lowercase keys ("psa", "1cor"). Returns null if not found.
  Book? _bookById(String id) {
    if (id.isEmpty) return null;
    final lower = id.toLowerCase();
    return _booksMap[lower] ??
        _booksMap[_booksMap.keys.firstWhere(
          (key) => key.toLowerCase() == lower,
          orElse: () => '',
        )];
  }

  List<Chapter> getChapters(String bookId) => _bookById(bookId)?.chapters ?? [];

  List<Verse> getVerses(String bookId, int chapterNumber) {
    if (chapterNumber < 1 || chapterNumber > getChapters(bookId).length) {
      return [];
    }
    return getChapters(bookId)[chapterNumber - 1].verses;
  }

  String getVerse(String bookId, int chapterNumber, int verseNumber) {
    if (verseNumber < 1 ||
        verseNumber > getVerses(bookId, chapterNumber).length) {
      return '';
    }
    return getVerses(bookId, chapterNumber)[verseNumber - 1].text.trim();
  }

  String getPassageRange(
    String bookId,
    int chapter,
    int startVerse, {
    int? endVerse,
  }) {
    // If no end specified, just return the single verse
    if (endVerse == null) {
      return getVerse(bookId, chapter, startVerse);
    }

    final verses = getVerses(bookId, chapter);
    final verseTexts = <String>[];
    for (int i = startVerse - 1; i < endVerse && i < verses.length; i++) {
      verseTexts.add(verses[i].text.trim());
    }

    return verseTexts.join('\n');
  }

  hasVerse(ScriptureRef ref) =>
      ref.complete &&
      getVerse(ref.bookId!, ref.chapterNumber!, ref.verseNumber!).isNotEmpty;

  getRefName(ScriptureRef ref) => refString(
    _bookById(ref.bookId!)?.title ?? 'Unknown',
    ref.chapterNumber,
    ref.verseNumber,
  );

  String getRangeRefName(ScriptureRangeRef ref) {
    final bookTitle = _booksMap.isNotEmpty
        ? (_bookById(ref.bookId)?.title ?? 'Unknown')
        : 'Unknown';

    if (ref.endVerse == null || ref.endVerse == ref.startVerse) {
      return '$bookTitle ${ref.chapter}:${ref.startVerse}';
    }
    return '$bookTitle ${ref.chapter}:${ref.startVerse}-${ref.endVerse}';
  }

  /// Validates and normalizes a passage reference coming from external
  /// recognition. Returns a [ScriptureRangeRef] using the canonical
  /// (lowercase) book id if the reference resolves to real verses in the
  /// loaded Bible, otherwise returns null.
  ScriptureRangeRef? resolveRangeRef(
    String bookId,
    int chapter,
    int startVerse,
    int? endVerse,
  ) {
    final book = _bookById(bookId);
    if (book == null || chapter < 1 || chapter > book.chapters.length) {
      return null;
    }

    final verses = book.chapters[chapter - 1].verses;
    if (startVerse < 1 || startVerse > verses.length) {
      return null;
    }

    final resolvedEnd = endVerse ?? startVerse;
    if (resolvedEnd < startVerse || resolvedEnd > verses.length) {
      return null;
    }

    return ScriptureRangeRef(
      bookId: book.id,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: resolvedEnd,
    );
  }
}
