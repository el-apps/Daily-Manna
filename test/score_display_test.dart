import 'package:daily_manna/services/score_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScoreDisplay', () {
    group('scoreToEmoji', () {
      test('returns 🌳 for 90-100%', () {
        expect(ScoreDisplay.scoreToEmoji(0.90), '🌳');
        expect(ScoreDisplay.scoreToEmoji(0.95), '🌳');
        expect(ScoreDisplay.scoreToEmoji(1.0), '🌳');
      });

      test('returns 🌲 for 80-89%', () {
        expect(ScoreDisplay.scoreToEmoji(0.80), '🌲');
        expect(ScoreDisplay.scoreToEmoji(0.85), '🌲');
        expect(ScoreDisplay.scoreToEmoji(0.89), '🌲');
      });

      test('returns 🌿 for 70-79%', () {
        expect(ScoreDisplay.scoreToEmoji(0.70), '🌿');
        expect(ScoreDisplay.scoreToEmoji(0.75), '🌿');
        expect(ScoreDisplay.scoreToEmoji(0.79), '🌿');
      });

      test('returns 🌰 for 0-69%', () {
        expect(ScoreDisplay.scoreToEmoji(0.0), '🌰');
        expect(ScoreDisplay.scoreToEmoji(0.50), '🌰');
        expect(ScoreDisplay.scoreToEmoji(0.69), '🌰');
      });
    });

    group('scoreToEmoji with attempts', () {
      test('shows growth emoji for single attempt', () {
        expect(ScoreDisplay.scoreToEmoji(0.95, attempts: 1), '🌳');
      });

      test('returns ♻️ for multiple attempts', () {
        expect(ScoreDisplay.scoreToEmoji(0.95, attempts: 2), '♻️');
        expect(ScoreDisplay.scoreToEmoji(0.75, attempts: 3), '♻️');
      });
    });
  });
}
