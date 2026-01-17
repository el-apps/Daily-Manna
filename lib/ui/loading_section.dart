import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';

class LoadingSection extends StatelessWidget {
  final String message;

  const LoadingSection({super.key, required this.message});

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      spacing: 24,
      children: [
        const SizedBox(height: 4),
        const CircularProgressIndicator(),
        Text(
          message,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
