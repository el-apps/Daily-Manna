import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Settings',
    showShareButton: false,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Coming soon...',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
