import 'package:daily_manna/models/recitation_result.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecitationResult', () {
    group('starRating: 0 stars (score < 0.1)', () {
      test('at lower bound', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.0,
        );
        expect(result.starRating, 0);
      });

      test('just below transition', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.09,
        );
        expect(result.starRating, 0);
      });
    });

    group('starRating: 1 star (score >= 0.1, < 0.3)', () {
      test('at lower boundary', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.1,
        );
        expect(result.starRating, 1);
      });

      test('in middle', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.2,
        );
        expect(result.starRating, 1);
      });

      test('just below transition', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.29,
        );
        expect(result.starRating, 1);
      });
    });

    group('starRating: 2 stars (score >= 0.3, < 0.5)', () {
      test('at lower boundary', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.31,
        );
        expect(result.starRating, 2);
      });

      test('in middle', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.4,
        );
        expect(result.starRating, 2);
      });

      test('just below transition', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.49,
        );
        expect(result.starRating, 2);
      });
    });

    group('starRating: 3 stars (score >= 0.5, < 0.7)', () {
      test('at lower boundary', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.5,
        );
        expect(result.starRating, 3);
      });

      test('in middle', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.6,
        );
        expect(result.starRating, 3);
      });

      test('just below transition', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.69,
        );
        expect(result.starRating, 3);
      });
    });

    group('starRating: 4 stars (score >= 0.71, < 0.9)', () {
      test('at lower boundary', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.71,
        );
        expect(result.starRating, 4);
      });

      test('in middle', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.8,
        );
        expect(result.starRating, 4);
      });

      test('just below transition', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.89,
        );
        expect(result.starRating, 4);
      });
    });

    group('starRating: 5 stars (score >= 0.9)', () {
      test('at lower boundary', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 0.9,
        );
        expect(result.starRating, 5);
      });

      test('at upper bound', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 1.0,
        );
        expect(result.starRating, 5);
      });

      test('clamped to 5 for score > 1.0', () {
        final result = RecitationResult(
          ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
          score: 1.5,
        );
        expect(result.starRating, 5);
      });
    });

    test('starDisplay: correct format for 5 stars', () {
      final result = RecitationResult(
        ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
        score: 1.0,
      );
      expect(result.starDisplay, '⭐⭐⭐⭐⭐');
    });

    test('starDisplay: correct format for 3 stars', () {
      final result = RecitationResult(
        ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
        score: 0.6,
      );
      expect(result.starDisplay, '⭐⭐⭐☆☆');
    });

    test('starDisplay: correct format for 0 stars', () {
      final result = RecitationResult(
        ref: ScriptureRangeRef(bookId: 'Gen', startChapter: 1, startVerse: 1),
        score: 0.0,
      );
      expect(result.starDisplay, '☆☆☆☆☆');
    });
  });
}
