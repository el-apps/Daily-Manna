/// Growth-themed emoji display for memorization scores.
///
/// Score ranges account for ~2-3% scoring imprecision.
/// Emoji use plant metaphors for positive, encouraging feedback.
class ScoreDisplay {
  /// Convert score (0.0-1.0) to growth emoji.
  ///
  /// 🌳 Flourishing (90-100)
  /// 🌿 Growing Strong (80-89)
  /// 🌱 Sprouting (70-79)
  /// 🌾 Seeds Planted (0-69)
  /// ♻️ Multiple attempts
  static String scoreToEmoji(double score, {int attempts = 1}) {
    if (attempts > 1) return '♻️';
    return switch (score) {
      >= 0.90 => '🌳',
      >= 0.80 => '🌿',
      >= 0.70 => '🌱',
      _ => '🌾',
    };
  }

  /// Grade descriptions for the About page.
  static const grades = [
    (emoji: '🌳', label: 'Flourishing', range: '90-100'),
    (emoji: '🌿', label: 'Growing Strong', range: '80-89'),
    (emoji: '🌱', label: 'Sprouting', range: '70-79'),
    (emoji: '🌾', label: 'Seeds Planted', range: '0-69'),
    (emoji: '♻️', label: 'Multiple attempts', range: null),
  ];
}
