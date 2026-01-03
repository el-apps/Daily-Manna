import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter/material.dart';

class BibleService {
  late BibleParser _parser;
  late List<Book> _books;
  late Map<String, Book> _booksMap;
  bool _isLoaded = false;

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

  List<Chapter> getChapters(String bookId) {
    return _booksMap[bookId]?.chapters ?? [];
  }

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

  String getPassageRange(String bookId, int startChapter, int startVerse,
      {int? endChapter, int? endVerse}) {
    // If no end specified, just return the single verse
    if (endChapter == null || endVerse == null) {
      return getVerse(bookId, startChapter, startVerse);
    }

    final verseTexts = <String>[];

    // If range is within same chapter
    if (endChapter == startChapter) {
      final verses = getVerses(bookId, startChapter);
      for (int i = startVerse - 1; i < endVerse && i < verses.length; i++) {
        verseTexts.add(verses[i].text.trim());
      }
    } else {
      // Range spans multiple chapters
      for (int chapter = startChapter; chapter <= endChapter; chapter++) {
        final verses = getVerses(bookId, chapter);
        final startV = chapter == startChapter ? startVerse : 1;
        final endV = chapter == endChapter ? endVerse : verses.length;

        for (int i = startV - 1; i < endV && i < verses.length; i++) {
          verseTexts.add(verses[i].text.trim());
        }
      }
    }

    return verseTexts.join(' ');
  }

  hasVerse(ScriptureRef ref) =>
      ref.complete &&
      getVerse(ref.bookId!, ref.chapterNumber!, ref.verseNumber!).isNotEmpty;

  getRefName(ScriptureRef ref) => refString(
    booksMap[ref.bookId]?.title ?? 'Unknown',
    ref.chapterNumber,
    ref.verseNumber,
  );

  String getRangeRefName(PassageRangeRef ref) {
    final bookTitle = _booksMap.isNotEmpty 
      ? (_booksMap[ref.bookId]?.title ?? 'Unknown')
      : 'Unknown';
    
    if (ref.endChapter == null || ref.endVerse == null) {
      return '$bookTitle ${ref.startChapter}:${ref.startVerse}';
    }
    if (ref.endChapter == ref.startChapter) {
      return '$bookTitle ${ref.startChapter}:${ref.startVerse}-${ref.endVerse}';
    }
    return '$bookTitle ${ref.startChapter}:${ref.startVerse}-${ref.endChapter}:${ref.endVerse}';
  }
}
