import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptureRangeRef', () {
    test('creates instance with required fields', () {
      final ref = ScriptureRangeRef(
        bookId: 'John',
        startChapter: 3,
        startVerse: 16,
      );

      expect(ref.bookId, 'John');
      expect(ref.startChapter, 3);
      expect(ref.startVerse, 16);
      expect(ref.endChapter, isNull);
      expect(ref.endVerse, isNull);
    });

    test('creates instance with end verse', () {
      final ref = ScriptureRangeRef(
        bookId: 'John',
        startChapter: 3,
        startVerse: 16,
        endChapter: 3,
        endVerse: 18,
      );

      expect(ref.endChapter, 3);
      expect(ref.endVerse, 18);
    });

    group('complete', () {
      test('returns true when all required fields are set', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, true);
      });

      test('returns false when bookId is empty', () {
        final ref = ScriptureRangeRef(
          bookId: '',
          startChapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when startChapter is 0', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          startChapter: 0,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when startVerse is 0', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 0,
        );

        expect(ref.complete, false);
      });

      test('returns true with end verse fields', () {
        final ref = ScriptureRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
          endChapter: 3,
          endVerse: 18,
        );

        expect(ref.complete, true);
      });
    });
  });
}
