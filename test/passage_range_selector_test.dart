import 'package:daily_manna/passage_range_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PassageRangeRef', () {
    test('creates instance with required fields', () {
      final ref = PassageRangeRef(
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
      final ref = PassageRangeRef(
        bookId: 'John',
        startChapter: 3,
        startVerse: 16,
        endChapter: 3,
        endVerse: 18,
      );

      expect(ref.endChapter, 3);
      expect(ref.endVerse, 18);
    });

    group('display', () {
      test('shows single verse when no end verse', () {
        final ref = PassageRangeRef(
          bookId: 'Genesis',
          startChapter: 1,
          startVerse: 1,
        );

        expect(ref.display, 'Genesis 1:1');
      });

      test('shows verse range in same chapter', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
          endChapter: 3,
          endVerse: 18,
        );

        expect(ref.display, 'John 3:16-18');
      });

      test('shows verse range across chapters', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
          endChapter: 4,
          endVerse: 5,
        );

        expect(ref.display, 'John 3:16-4:5');
      });

      test('shows single verse with end chapter only', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
          endChapter: 3,
        );

        expect(ref.display, 'John 3:16');
      });
    });

    group('complete', () {
      test('returns true when all required fields are set', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, true);
      });

      test('returns false when bookId is empty', () {
        final ref = PassageRangeRef(
          bookId: '',
          startChapter: 3,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when startChapter is 0', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 0,
          startVerse: 16,
        );

        expect(ref.complete, false);
      });

      test('returns false when startVerse is 0', () {
        final ref = PassageRangeRef(
          bookId: 'John',
          startChapter: 3,
          startVerse: 0,
        );

        expect(ref.complete, false);
      });

      test('returns true with end verse fields', () {
        final ref = PassageRangeRef(
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
