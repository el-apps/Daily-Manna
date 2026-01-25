import 'package:flutter/material.dart';

/// A row with a secondary (outlined) and primary (filled) action button.
class ActionButtonRow extends StatelessWidget {
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  const ActionButtonRow({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondary,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onSecondary,
          child: Text(secondaryLabel),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: FilledButton(
          onPressed: onPrimary,
          child: Text(primaryLabel),
        ),
      ),
    ],
  );
}
