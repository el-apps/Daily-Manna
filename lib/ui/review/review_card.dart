import 'package:daily_manna/services/spaced_repetition_service.dart';
import 'package:daily_manna/ui/count_badge.dart';
import 'package:daily_manna/ui/review/review_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Home page card showing review queue with due count badge.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final srService = context.read<SpacedRepetitionService>();

    return FutureBuilder<int>(
      future: srService.getDueCount(),
      builder: (context, snapshot) {
        final dueCount = snapshot.data ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card.filled(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 24,
              ),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Review',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (dueCount > 0) ...[
                    const SizedBox(width: 8),
                    CountBadge(count: dueCount),
                  ],
                ],
              ),
              trailing: const Icon(Icons.assignment),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReviewPage()),
              ),
            ),
          ),
        );
      },
    );
  }
}
