import 'package:daily_manna/share_dialog.dart';
import 'package:flutter/material.dart';

/// A scaffold wrapper that provides consistent AppBar and share button across the app.
///
/// The share button is available on all screens except Settings.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showShareButton;
  final List<Widget>? appBarActions;
  final FloatingActionButton? floatingActionButton;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showShareButton = true,
    this.appBarActions,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      ...?appBarActions,
      if (showShareButton)
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () =>
              showDialog(context: context, builder: (_) => const ShareDialog()),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions.isNotEmpty ? actions : null,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      backgroundColor: backgroundColor,
    );
  }
}
