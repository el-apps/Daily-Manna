import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptureRangeRef', () {
    test('creates instance with required fields', () {
      final ref = ScriptureRangeRef(
        bookId: 'John',
        chapter: 3,
        startVerse: 16,
      );

      expect(ref.bookId, 'John');
      expect(ref.chapter, 3);
      expect(ref.startVerse, 16);
      expect(ref.endVerse, isNull);
    });

    test('creates instance with end verse', () {
      final ref = ScriptureRangeRef(
        bookId: 'John',
        chapter: 3,
        startVerse: 16,
        endVerse: 18,
      );

      expect(ref.endVerse, 18);
    });

    group('complete', () {
      test('returns true when all required fields are set', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          chapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, true);
      });

      test('returns false when bookId is empty', () {
        final ref = ScriptureRangeRef(
          bookId: '',
          chapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when chapter is 0', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          chapter: 0,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when startVerse is 0', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          chapter: 3,
          startVerse: 0,
        );

        expect(ref.complete, false);
      });

      test('returns true with end verse field', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          chapter: 3,
          startVerse: 16,
          endVerse: 18,
        );

        expect(ref.complete, true);
      });
    });
  });
}
