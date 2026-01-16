import 'package:flutter/material.dart';

/// A reusable card widget with consistent styling across the app.
/// Used for displaying content blocks with background, border, and padding.
class ThemeCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double padding;

  const ThemeCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor ?? Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}
