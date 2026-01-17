import 'package:daily_manna/models/scripture_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptureRef', () {
    test('creates instance with all fields', () {
      final ref = ScriptureRef(
        bookId: 'John',
        chapterNumber: 3,
        verseNumber: 16,
      );

      expect(ref.bookId, 'John');
      expect(ref.chapterNumber, 3);
      expect(ref.verseNumber, 16);
    });

    test('creates instance with null fields', () {
      final ref = ScriptureRef();

      expect(ref.bookId, isNull);
      expect(ref.chapterNumber, isNull);
      expect(ref.verseNumber, isNull);
    });

    test('creates instance with partial fields', () {
      final ref = ScriptureRef(bookId: 'John', chapterNumber: 3);

      expect(ref.bookId, 'John');
      expect(ref.chapterNumber, 3);
      expect(ref.verseNumber, isNull);
    });

    group('complete', () {
      test('returns true when all fields are set', () {
        final ref = ScriptureRef(
          bookId: 'John',
          chapterNumber: 3,
          verseNumber: 16,
        );

        expect(ref.complete, true);
      });

      test('returns false when bookId is null', () {
        final ref = ScriptureRef(chapterNumber: 3, verseNumber: 16);

        expect(ref.complete, false);
      });

      test('returns false when chapterNumber is null', () {
        final ref = ScriptureRef(bookId: 'John', verseNumber: 16);

        expect(ref.complete, false);
      });

      test('returns false when verseNumber is null', () {
        final ref = ScriptureRef(bookId: 'John', chapterNumber: 3);

        expect(ref.complete, false);
      });

      test('returns false when all fields are null', () {
        final ref = ScriptureRef();

        expect(ref.complete, false);
      });
    });

    group('toString', () {
      test('returns book name only when chapter is null', () {
        final ref = ScriptureRef(bookId: 'John');

        expect(ref.toString(), 'John');
      });

      test('returns book and chapter when verse is null', () {
        final ref = ScriptureRef(bookId: 'John', chapterNumber: 3);

        expect(ref.toString(), 'John 3');
      });

      test('returns full reference when all fields are set', () {
        final ref = ScriptureRef(
          bookId: 'John',
          chapterNumber: 3,
          verseNumber: 16,
        );

        expect(ref.toString(), 'John 3:16');
      });

      test('returns Unknown when bookId is null', () {
        final ref = ScriptureRef(chapterNumber: 3, verseNumber: 16);

        expect(ref.toString(), 'Unknown');
      });
    });
  });

  group('refString', () {
    test('returns book title only when chapter is null', () {
      expect(refString('John', null, null), 'John');
    });

    test('returns book and chapter when verse is null', () {
      expect(refString('John', 3, null), 'John 3');
    });

    test('returns full reference when all parameters are provided', () {
      expect(refString('John', 3, 16), 'John 3:16');
    });

    test('returns Unknown when book title is null', () {
      expect(refString(null, 3, 16), 'Unknown');
    });

    test('returns Unknown when all parameters are null', () {
      expect(refString(null, null, null), 'Unknown');
    });
  });
}
