import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/services/score_display.dart';
import 'package:daily_manna/ui/score_emoji.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareDialog extends StatelessWidget {
  const ShareDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final resultsService = context.read<ResultsService>();

    return FutureBuilder<List<ResultSection>>(
      future: resultsService.getTodaySections(bibleService),
      builder: (context, snapshot) {
        final sections = snapshot.data ?? [];
        final hasContent = sections.isNotEmpty;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return AlertDialog(
          title: const Text('Share Your Progress'),
          content: isLoading
              ? const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily sharing your results with others is a great way to practice accountability!',
                    ),
                    if (hasContent) ...[
                      const Divider(),
                      ...sections.expand(
                        (section) => [
                          Text(
                            section.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...section.items.map(
                            (item) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ScoreEmoji(
                                  score: item.score,
                                  attempts: item.attempts,
                                  fontSize: 18,
                                ),
                                Text(item.reference),
                              ],
                            ),
                          ),
                          if (section != sections.last)
                            const SizedBox(height: 8),
                        ],
                      ),
                    ] else ...[
                      const Divider(),
                      Text(
                        'No results to share yet today. Complete a memorization or recitation to get started.',
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (hasContent && !isLoading)
              TextButton(
                onPressed: () => _share(context, sections),
                child: const Text('Share'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _share(
    BuildContext context,
    List<ResultSection> sections,
  ) async {
    final shareContent = sections
        .map(
          (section) => [
            section.title,
            ...section.items.map(
              (item) =>
                  '${ScoreDisplay.scoreToEmoji(item.score, attempts: item.attempts)} ${item.reference}',
            ),
          ].join('\n'),
        )
        .join('\n\n');

    await SharePlus.instance.share(
      ShareParams(text: 'Daily Manna Results\n\n$shareContent'),
    );
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
