import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BibleService {
  late BibleParser _parser;
  late List<Book> _books;
  late Map<String, Book> _booksMap;
  bool _isLoaded = false;

  get isLoaded => _isLoaded;
  List<Book> get books => _books;
  Map<String, Book> get booksMap => _booksMap;

  Future load([BuildContext? context]) async {
    final bundle = context == null
        ? rootBundle
        : DefaultAssetBundle.of(context);
    final xmlString = await bundle.loadString('assets/kjv.xml');
    _parser = BibleParser.fromString(xmlString, format: 'OSIS');
    _books = (await _parser.books.toList())
        .where((b) => b.title != 'Unknown')
        .toList();
    _booksMap = Map.fromEntries(_books.map((b) => MapEntry(b.id, b)));
    _isLoaded = true;
  }

  List<Chapter> getChapters(String bookId) => _booksMap[bookId]?.chapters ?? [];

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
    int? endChapter,
    int? endVerse,
  }) {
    if (endChapter != null && endChapter != chapter) {
      return [
        for (var current = chapter; current <= endChapter; current++)
          getPassageRange(
            bookId,
            current,
            current == chapter ? startVerse : 1,
            endVerse: current == endChapter
                ? endVerse ?? startVerse
                : getVerses(bookId, current).length,
          ),
      ].join('\n');
    }
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
    booksMap[ref.bookId]?.title ?? 'Unknown',
    ref.chapterNumber,
    ref.verseNumber,
  );

  String getRangeRefName(ScriptureRangeRef ref) {
    if (ref.endChapter != null && ref.endChapter != ref.chapter) {
      return getReadingName(
        bookId: ref.bookId,
        startChapter: ref.chapter,
        startVerse: ref.startVerse,
        endChapter: ref.endChapter!,
        endVerse: ref.endVerse ?? ref.startVerse,
      );
    }
    final bookTitle = booksMap[ref.bookId]?.title ?? 'Unknown';

    if (ref.endVerse == null || ref.endVerse == ref.startVerse) {
      return '$bookTitle ${ref.chapter}:${ref.startVerse}';
    }
    return '$bookTitle ${ref.chapter}:${ref.startVerse}-${ref.endVerse}';
  }

  /// Formats a stored reading, including whole chapters and cross-chapter ranges.
  String getReadingName({
    required String bookId,
    required int startChapter,
    required int startVerse,
    required int endChapter,
    required int endVerse,
  }) {
    final title = booksMap[bookId]?.title ?? 'Unknown';
    if (startVerse == 1 && endVerse == getVerses(bookId, endChapter).length) {
      return startChapter == endChapter
          ? '$title $startChapter'
          : '$title $startChapter–$endChapter';
    }
    final start = '$title $startChapter:$startVerse';
    if (startChapter != endChapter) return '$start–$endChapter:$endVerse';
    return startVerse == endVerse ? start : '$start–$endVerse';
  }
}
