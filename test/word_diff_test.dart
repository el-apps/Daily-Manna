import 'package:daily_manna/word_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeWordDiff', () {
    test('exact match returns all correct', () {
      const original = 'In the beginning was the Word';
      const transcribed = 'In the beginning was the Word';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 6);
      expect(diff.every((w) => w.status == DiffStatus.correct), true);
    });

    test('extra words are marked as extra', () {
      const original = 'In the beginning';
      const transcribed = 'In the beginning and more';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 5);
      final correct = diff
          .where((w) => w.status == DiffStatus.correct)
          .toList();
      expect(correct.length, 3);
      final extra = diff.where((w) => w.status == DiffStatus.extra).toList();
      expect(extra.length, 2);
    });

    test('missing words are marked as missing', () {
      const original = 'In the beginning was the Word';
      const transcribed = 'In beginning Word';

      final diff = computeWordDiff(original, transcribed);

      expect(diff[0].text, 'In');
      expect(diff[0].status, DiffStatus.correct);
      expect(diff[1].text, 'the');
      expect(diff[1].status, DiffStatus.missing);
      expect(diff[2].text, 'beginning');
      expect(diff[2].status, DiffStatus.correct);
      expect(diff[3].text, 'was');
      expect(diff[3].status, DiffStatus.missing);
      expect(diff[4].text, 'the');
      expect(diff[4].status, DiffStatus.missing);
      expect(diff[5].text, 'Word');
      expect(diff[5].status, DiffStatus.correct);
    });

    test('ignores punctuation when matching', () {
      const original = 'In the beginning was the Word.';
      const transcribed = 'In the beginning was the Word';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 6);
      expect(diff.every((w) => w.status == DiffStatus.correct), true);
    });

    test('case insensitive matching', () {
      const original = 'In the beginning was the Word';
      const transcribed = 'in THE beginning WAS the word';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 6);
      expect(diff.every((w) => w.status == DiffStatus.correct), true);
    });

    test('John 1:1-3 missing verse 2', () {
      const original =
          '''In the beginning was the Word, and the Word was with God, and the Word was God. The same was in the beginning with God. All things were made by him; and without him was not any thing made that was made.''';

      // User recites verses 1 and 3 but skips verse 2
      const transcribed =
          '''In the beginning was the Word, and the Word was with God, and the Word was God.
All things were made by him; and without him was not any thing made that was made.''';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 42);

      // Verse 1: all 17 words correct
      for (int i = 0; i < 17; i++) {
        expect(diff[i].status, DiffStatus.correct,
            reason: 'Verse 1 word $i should be correct');
      }

      // Verse 2: all 8 words missing
      for (int i = 17; i < 25; i++) {
        expect(diff[i].status, DiffStatus.missing,
            reason: 'Verse 2 word ${i - 17} should be missing');
      }

      // Verse 3: all 17 words correct
      for (int i = 25; i < 42; i++) {
        expect(diff[i].status, DiffStatus.correct,
            reason: 'Verse 3 word ${i - 25} should be correct');
      }
    });

    test('transposed adjacent words', () {
      const original = 'In the beginning was the Word';
      const transcribed = 'In the beginning was Word the';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 7);
      expect(diff[0].text, 'In');
      expect(diff[0].status, DiffStatus.correct);
      expect(diff[1].text, 'the');
      expect(diff[1].status, DiffStatus.correct);
      expect(diff[2].text, 'beginning');
      expect(diff[2].status, DiffStatus.correct);
      expect(diff[3].text, 'was');
      expect(diff[3].status, DiffStatus.correct);
      expect(diff[4].text, 'Word');
      expect(diff[4].status, DiffStatus.extra);
      expect(diff[5].text, 'the');
      expect(diff[5].status, DiffStatus.correct);
      expect(diff[6].text, 'Word');
      expect(diff[6].status, DiffStatus.missing);
    });

    test('transposed non-adjacent words', () {
      const original = 'In the beginning was the Word';
      const transcribed = 'Word the beginning was the In';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 8);
      expect(diff[0].text, 'In');
      expect(diff[0].status, DiffStatus.missing);
      expect(diff[1].text, 'Word');
      expect(diff[1].status, DiffStatus.extra);
      expect(diff[2].text, 'the');
      expect(diff[2].status, DiffStatus.correct);
      expect(diff[3].text, 'beginning');
      expect(diff[3].status, DiffStatus.correct);
      expect(diff[4].text, 'was');
      expect(diff[4].status, DiffStatus.correct);
      expect(diff[5].text, 'the');
      expect(diff[5].status, DiffStatus.correct);
      expect(diff[6].text, 'Word');
      expect(diff[6].status, DiffStatus.missing);
      expect(diff[7].text, 'In');
      expect(diff[7].status, DiffStatus.extra);
    });

    test('synonym substitution (God → Lord)', () {
      const original = 'and the Word was with God';
      const transcribed = 'and the Word was with Lord';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 7);
      expect(diff[0].text, 'and');
      expect(diff[0].status, DiffStatus.correct);
      expect(diff[1].text, 'the');
      expect(diff[1].status, DiffStatus.correct);
      expect(diff[2].text, 'Word');
      expect(diff[2].status, DiffStatus.correct);
      expect(diff[3].text, 'was');
      expect(diff[3].status, DiffStatus.correct);
      expect(diff[4].text, 'with');
      expect(diff[4].status, DiffStatus.correct);
      expect(diff[5].text, 'God');
      expect(diff[5].status, DiffStatus.missing);
      expect(diff[6].text, 'Lord');
      expect(diff[6].status, DiffStatus.extra);
    });

    test('phrase reordering within verse', () {
      const original = 'and the Word was with God and the Word was God';
      // User mixes up: puts "was God" before "was with God"
      const transcribed = 'and the Word was God and the Word was with God';

      final diff = computeWordDiff(original, transcribed);

      expect(diff.length, 12);
      expect(diff[0].text, 'and');
      expect(diff[0].status, DiffStatus.correct);
      expect(diff[1].text, 'the');
      expect(diff[1].status, DiffStatus.correct);
      expect(diff[2].text, 'Word');
      expect(diff[2].status, DiffStatus.correct);
      expect(diff[3].text, 'was');
      expect(diff[3].status, DiffStatus.correct);
      expect(diff[4].text, 'with');
      expect(diff[4].status, DiffStatus.missing);
      expect(diff[5].text, 'God');
      expect(diff[5].status, DiffStatus.correct);
      expect(diff[6].text, 'and');
      expect(diff[6].status, DiffStatus.correct);
      expect(diff[7].text, 'the');
      expect(diff[7].status, DiffStatus.correct);
      expect(diff[8].text, 'Word');
      expect(diff[8].status, DiffStatus.correct);
      expect(diff[9].text, 'was');
      expect(diff[9].status, DiffStatus.correct);
      expect(diff[10].text, 'with');
      expect(diff[10].status, DiffStatus.extra);
      expect(diff[11].text, 'God');
      expect(diff[11].status, DiffStatus.correct);
    });
  });
}
