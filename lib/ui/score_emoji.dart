import 'package:daily_manna/about_page.dart';
import 'package:daily_manna/services/score_display.dart';
import 'package:flutter/material.dart';

/// Displays growth emoji for a score. Taps open About page.
class ScoreEmoji extends StatelessWidget {
  final double score;
  final int attempts;
  final double fontSize;

  const ScoreEmoji({
    super.key,
    required this.score,
    this.attempts = 1,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
    child: Text(
      ScoreDisplay.scoreToEmoji(score, attempts: attempts),
      style: TextStyle(fontSize: fontSize),
    ),
  );
}
