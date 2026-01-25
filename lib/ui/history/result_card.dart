import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/utils/date_utils.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/score_emoji.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ResultCard extends StatelessWidget {
  final Result result;
  final String reference;
  final ScoreData score;
  final VoidCallback? onPractice;

  const ResultCard({
    super.key,
    required this.result,
    required this.reference,
    required this.score,
    this.onPractice,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reference, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _TypeBadge(type: result.type),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(result.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ScoreEmoji(score: score, fontSize: 20),
              if (onPractice != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onPractice,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Practice'),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = now.dateOnly;
    final date = timestamp.dateOnly;

    if (date == today) {
      return DateFormat.jm().format(timestamp);
    }
    return DateFormat.MMMd().add_jm().format(timestamp);
  }
}

class _TypeBadge extends StatelessWidget {
  final ResultType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      ResultType.recitation => ('Recitation', Colors.blue),
      ResultType.memorization => ('Memorization', Colors.green),
      ResultType.study => ('Study', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
