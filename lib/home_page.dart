import 'package:daily_manna/mode_card.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/interaction_sheet.dart';
import 'package:daily_manna/ui/streak/streak_card.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Daily Manna',
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'An app for building strong daily habits in interacting with the Word of God.',
            style: Theme.of(
              context,
            ).textTheme.titleSmall!.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        const StreakCard(),
        ModeCard(
          title: 'Interact',
          icon: Icons.play_arrow,
          onTap: () => _startInteraction(context),
        ),
        ModeCard(
          title: 'History',
          icon: Icons.history,
          onTap: () => context.push('/history'),
        ),
        ModeCard(
          title: 'Settings',
          icon: Icons.settings,
          onTap: () => context.push('/settings'),
        ),
        ModeCard(
          title: 'About',
          icon: Icons.info_outline,
          onTap: () => context.push('/about'),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _startInteraction(context),
      child: const Icon(Icons.play_arrow),
    ),
  );

  Future<void> _startInteraction(BuildContext context) async {
    final passage = await showPassageSelector(context);
    if (context.mounted && passage != null) {
      showPassageInteractionSheet(context, passage);
    }
  }
}
