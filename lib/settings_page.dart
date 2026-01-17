import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Settings',
    showShareButton: false,
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        Text(
          'Daily Manna',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Text(
          'Build strong daily habits in interacting with the Word of God.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Text(
          'About',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'This app helps you memorize Bible verses through daily practice and recitation.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
