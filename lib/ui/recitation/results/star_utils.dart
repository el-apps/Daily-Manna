import 'package:flutter/material.dart';

class StarUtils {
  /// Convert score (0.0-1.0) to star count (0-5)
  static int scoreToStars(double score) => (score * 5).round().clamp(0, 5);

  /// Build star rating widget
  static Widget buildStarDisplay(double score) {
    final stars = scoreToStars(score);
    final emptyStars = 5 - stars;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(stars, (_) => const Icon(Icons.star, color: Colors.amber)),
        ...List.generate(
          emptyStars,
          (_) => const Icon(Icons.star_outline, color: Colors.amber),
        ),
      ],
    );
  }
}
