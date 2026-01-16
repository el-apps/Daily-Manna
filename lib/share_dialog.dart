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
    final shareContent = [
      [
        'Memorization',
        ...resultsService.memorizationResults.map(
          (result) =>
              '${result.scoreString} ${bibleService.getRefName(result.ref)}',
        ),
      ].join('\n'),
      [
        'Recitation',
        ...resultsService.recitationResults.map(
          (result) =>
              '${result.starDisplay} ${bibleService.getRangeRefName(result.ref)}',
        ),
      ].join('\n'),
    ].where((section) => section.isNotEmpty).join('\n----------\n');
    return AlertDialog(
      title: Text('Share Your Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily sharing your results with others is a great way to practice accountability!',
          ),
          if (shareContent.isNotEmpty) Divider(),
          Text(shareContent),
        ],
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        if (shareContent.isNotEmpty)
          TextButton(
            onPressed: () => _share(context, shareContent),
            child: Text('Share'),
          ),
      ],
    );
  }

  Future<void> _share(BuildContext context, String shareContent) async {
    await SharePlus.instance.share(
      ShareParams(text: 'Daily Manna Results\n\n$shareContent'),
    );
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
