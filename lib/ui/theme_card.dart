import 'package:flutter/material.dart';

enum ThemeCardStyle { neutral, brown, blue, green, red }

/// A reusable card widget with consistent styling across the app.
/// Used for displaying content blocks with background, border, and padding.
class ThemeCard extends StatelessWidget {
  final Widget child;
  final ThemeCardStyle style;

  const ThemeCard({
    super.key,
    required this.child,
    this.style = ThemeCardStyle.brown,
  });

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, borderColor) = _getColors();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  (Color, Color) _getColors() {
    switch (style) {
      case ThemeCardStyle.neutral:
        return (
          Colors.grey.withValues(alpha: 0.1),
          Colors.grey.withValues(alpha: 0.3),
        );
      case ThemeCardStyle.brown:
        return (Colors.brown.withValues(alpha: 0.1), Colors.brown);
      case ThemeCardStyle.blue:
        return (Colors.blue.withValues(alpha: 0.1), Colors.blue);
      case ThemeCardStyle.green:
        return (Colors.green.withValues(alpha: 0.1), Colors.green);
      case ThemeCardStyle.red:
        return (Colors.red.withValues(alpha: 0.1), Colors.red);
    }
  }
}
