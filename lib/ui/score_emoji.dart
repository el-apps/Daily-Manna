import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/services/score_display.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Displays growth emoji for a score. Taps open About page.
class ScoreEmoji extends StatelessWidget {
  final ScoreData score;
  final double fontSize;

  const ScoreEmoji({super.key, required this.score, this.fontSize = 24});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.push('/about'),
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        ScoreDisplay.scoreToEmoji(score.value, attempts: score.attempts),
        style: TextStyle(fontSize: fontSize),
      ),
    ),
  );
}
