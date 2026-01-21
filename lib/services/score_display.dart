/// Growth-themed emoji display for memorization scores.
///
/// Score ranges account for ~2-3% scoring imprecision.
/// Emoji use forest tree metaphors for positive, encouraging feedback.
class ScoreDisplay {
  /// Convert score (0.0-1.0) to growth emoji.
  ///
  /// 🌳 Mighty Oak (90-100)
  /// 🌲 Growing Tree (80-89)
  /// 🌿 Sapling (70-79)
  /// 🌰 Acorn (0-69)
  /// ♻️ Multiple attempts
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
    (emoji: '🌳', label: 'Mighty Oak', range: '90-100'),
    (emoji: '🌲', label: 'Growing Tree', range: '80-89'),
    (emoji: '🌿', label: 'Sapling', range: '70-79'),
    (emoji: '🌰', label: 'Acorn', range: '0-69'),
    (emoji: '♻️', label: 'Multiple attempts', range: null),
  ];
}
