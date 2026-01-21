/// Growth-themed emoji display for memorization scores.
///
/// Score ranges account for ~2-3% scoring imprecision.
/// Emoji use forest tree metaphors for positive, encouraging feedback.
class ScoreDisplay {
  /// Convert score (0.0-1.0) to growth emoji.
  ///
  /// 🌳 Mastered (90-100)
  /// 🌲 Almost There (80-89)
  /// 🌿 Growing (70-79)
  /// 🌰 Planted (0-69)
  /// ♻️ Persevered
  static String scoreToEmoji(double score, {int attempts = 1}) {
    if (attempts > 1) return '♻️';
    return switch (score) {
      >= 0.90 => '🌳',
      >= 0.80 => '🌲',
      >= 0.70 => '🌿',
      _ => '🌰',
    };
  }

  /// Grade descriptions for the About page.
  static const grades = [
    (emoji: '🌳', label: 'Mastered', range: '90-100'),
    (emoji: '🌲', label: 'Almost There', range: '80-89'),
    (emoji: '🌿', label: 'Growing', range: '70-79'),
    (emoji: '🌰', label: 'Planted', range: '0-69'),
    (emoji: '♻️', label: 'Persevered', range: null),
  ];
}
