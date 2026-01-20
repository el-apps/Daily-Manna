import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemorizationResult', () {
    final ref = ScriptureRef(bookId: 'jas', chapterNumber: 1, verseNumber: 1);

    test('scoreString returns 🌳 for high score single attempt', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.95);
      expect(result.scoreString, '🌳');
    });

    test('scoreString returns 🌿 for 80-89% score', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.85);
      expect(result.scoreString, '🌿');
    });

    test('scoreString returns 🌳♻️ for high score multiple attempts', () {
      final result = MemorizationResult(ref: ref, attempts: 2, score: 0.95);
      expect(result.scoreString, '🌳♻️');
    });

    test('scoreString returns 🌾♻️ for low score multiple attempts', () {
      final result = MemorizationResult(ref: ref, attempts: 2, score: 0.50);
      expect(result.scoreString, '🌾♻️');
    });

    test('scoreString returns 🌾 for low score single attempt', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.49);
      expect(result.scoreString, '🌾');
    });

    test('scoreString returns 🌱 for 70-79% score', () {
      final result = MemorizationResult(ref: ref, attempts: 1, score: 0.75);
      expect(result.scoreString, '🌱');
    });
  });
}
