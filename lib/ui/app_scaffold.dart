import 'package:daily_manna/share_dialog.dart';
import 'package:flutter/material.dart';

/// A scaffold wrapper that provides consistent AppBar and share button across the app.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showShareButton;
  final List<Widget>? appBarActions;
  final PreferredSizeWidget? bottom;
  final FloatingActionButton? floatingActionButton;
  final Color? backgroundColor;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showShareButton = true,
    this.appBarActions,
    this.bottom,
    this.floatingActionButton,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      bottom: bottom,
      actions: [
        ...?appBarActions,
        if (showShareButton)
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ShareDialog(),
            ),
          ),
      ],
    ),
    body: body,
    floatingActionButton: floatingActionButton,
    backgroundColor: backgroundColor,
  );
}
