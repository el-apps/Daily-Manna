import 'package:daily_manna/practice_result.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemorizationResult', () {
    final ref = ScriptureRef(bookId: 'jas', chapterNumber: 1, verseNumber: 1);

    test('scoreString returns 🎉 for 1 attempt and score 0.9', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.9);
      expect(result.scoreString, '🎉');
    });

    test('scoreString returns ✅ for 1 attempt and score 0.89', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.89);
      expect(result.scoreString, '✅');
    });

    test('scoreString returns ♻️ for 2 attempts and score 0.9', () {
      final result = MemorizationResult(ref: ref, attempts: 2, score: 0.9);
      expect(result.scoreString, '♻️');
    });

    test('scoreString returns ♻️ for 2 attempts and score 0.5', () {
      final result2 = MemorizationResult(ref: ref, attempts: 2, score: 0.5);
      expect(result2.scoreString, '♻️');
    });

    test('scoreString returns ⛔ for 1 attempt and score 0.49', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.49);
      expect(result.scoreString, '⛔');
    });

    test('scoreString returns ⛔ for 2 attempts and score 0.49', () {
      final result = MemorizationResult(ref: ref, attempts: 2, score: 0.49);
      expect(result.scoreString, '⛔');
    });
  });
}
