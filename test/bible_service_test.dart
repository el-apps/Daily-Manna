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
}

BibleService _createTestBibleService() =>
    BibleService.fromBooks([
      Book(id: 'gen', num: 1, title: 'Genesis'),
      Book(id: 'john', num: 43, title: 'John'),
    ]);
