import 'package:bible_parser_flutter/bible_parser_flutter.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BibleService.getRangeRefName', () {
    late BibleService bibleService;

    setUp(() {
      bibleService = _createTestBibleService();
    });

    test('shows single verse when no end verse', () {
      final ref = ScriptureRangeRef(bookId: 'gen', chapter: 1, startVerse: 1);

      expect(bibleService.getRangeRefName(ref), 'Genesis 1:1');
    });

    test('shows verse range in same chapter', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        chapter: 3,
        startVerse: 16,
        endVerse: 18,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16-18');
    });

    test('shows single verse when endVerse equals startVerse', () {
      final ref = ScriptureRangeRef(
        bookId: 'john',
        chapter: 3,
        startVerse: 16,
        endVerse: 16,
      );

      expect(bibleService.getRangeRefName(ref), 'John 3:16');
    });

    test('resolves capitalized book id returned by recognition', () {
      final ref = ScriptureRangeRef(bookId: 'Gen', chapter: 1, startVerse: 1);

      expect(bibleService.getRangeRefName(ref), 'Genesis 1:1');
    });

    test('falls back to Unknown for unrecognized book id', () {
      final ref = ScriptureRangeRef(bookId: 'Xxx', chapter: 1, startVerse: 1);

      expect(bibleService.getRangeRefName(ref), 'Unknown 1:1');
    });
  });

  group('BibleService.resolveRangeRef', () {
    late BibleService bibleService;

    setUp(() {
      bibleService = _createTestBibleService();
    });

    test('resolves a valid reference and canonicalizes book id casing', () {
      final resolved = bibleService.resolveRangeRef(
        'Gen',
        1,
        1,
        null,
      );

      expect(resolved, isNotNull);
      expect(resolved!.bookId, 'gen');
      expect(resolved.chapter, 1);
      expect(resolved.startVerse, 1);
      expect(resolved.endVerse, 1);
    });

    test('returns null for an unknown book id', () {
      expect(bibleService.resolveRangeRef('Xxx', 1, 1, null), isNull);
    });

    test('returns null for a chapter that does not exist', () {
      expect(bibleService.resolveRangeRef('gen', 99, 1, null), isNull);
    });

    test('returns null for a verse beyond the chapter', () {
      expect(bibleService.resolveRangeRef('gen', 1, 99, null), isNull);
    });

    test('returns null when endVerse is before startVerse', () {
      expect(bibleService.resolveRangeRef('gen', 1, 5, 3), isNull);
    });

    test('returns null when endVerse exceeds the chapter', () {
      expect(bibleService.resolveRangeRef('gen', 1, 1, 99), isNull);
    });

    test('preserves a valid verse range', () {
      final resolved = bibleService.resolveRangeRef('gen', 1, 1, 3);

      expect(resolved, isNotNull);
      expect(resolved!.chapter, 1);
      expect(resolved.startVerse, 1);
      expect(resolved.endVerse, 3);
    });
  });
}

BibleService _createTestBibleService() {
  final gen = Book(id: 'gen', num: 1, title: 'Genesis');
  final gen1 = Chapter(num: 1, bookId: 'gen');
  for (var i = 1; i <= 31; i++) {
    gen1.addVerse(
      Verse(num: i, chapterNum: 1, bookId: 'gen', text: 'verse $i'),
    );
  }
  gen.addChapter(gen1);

  final john = Book(id: 'john', num: 43, title: 'John');
  final john3 = Chapter(num: 3, bookId: 'john');
  for (var i = 1; i <= 36; i++) {
    john3.addVerse(
      Verse(num: i, chapterNum: 3, bookId: 'john', text: 'verse $i'),
    );
  }
  john.addChapter(john3);

  return BibleService.fromBooks([gen, john]);
}
