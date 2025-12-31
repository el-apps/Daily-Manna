import 'package:flutter/material.dart';

class ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ModeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card.filled(
      child: ListTile(
        contentPadding: const EdgeInsetsGeometry.symmetric(
          vertical: 16,
          horizontal: 24,
        ),
        leading: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Icon(icon),
        onTap: onTap,
      ),
    ),
  );
}
