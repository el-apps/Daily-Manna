import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/practice_result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareDialog extends StatelessWidget {
  const ShareDialog({super.key, required this.memorizationResults});

  // TODO: fetch these from the DB
  final List<MemorizationResult> memorizationResults;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final shareContent = [
      [
        'Memorization',
        ...memorizationResults.map(
          (result) =>
              '${result.scoreString} ${bibleService.getRefName(result.ref)}',
        ),
      ].join('\n'),
      // TODO: add results from other parts of the app
    ].where((section) => section.isNotEmpty).join('----------\n');
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

  _share(BuildContext context, String shareContent) async {
    await SharePlus.instance.share(
      ShareParams(text: 'Daily Manna Results\n\n$shareContent'),
    );
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
