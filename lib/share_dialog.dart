import 'package:daily_manna/models/result_section.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareDialog extends StatelessWidget {
  const ShareDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final resultsService = context.read<ResultsService>();

    final sections = resultsService.getSections(bibleService);
    final hasContent = sections.isNotEmpty;

    return AlertDialog(
      title: Text('Share Your Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily sharing your results with others is a great way to practice accountability!',
          ),
          if (hasContent) ...[
            Divider(),
            ...sections.expand(
              (section) => [
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...section.items.map(
                  (item) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(item.score), Text(item.reference)],
                  ),
                ),
                if (section != sections.last) SizedBox(height: 8),
              ],
            ),
          ] else ...[
            Divider(),
            Text(
              'No results to share yet. Complete a memorization or recitation to get started.',
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
          child: Text('Cancel'),
        ),
        if (hasContent)
          TextButton(
            onPressed: () => _share(context, sections),
            child: Text('Share'),
          ),
      ],
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
            ...section.items.map((item) => '${item.score} ${item.reference}'),
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
