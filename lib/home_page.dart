import 'package:daily_manna/about_page.dart';
import 'package:daily_manna/mode_card.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/history/history_page.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/ui/review/review_card.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Feature> features = const [
    (title: 'Recite', icon: Icons.mic, widget: RecitationMode()),
    (title: 'Memorize', icon: Icons.voice_chat, widget: VerseMemorization()),
  ];

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
        const ReviewCard(),
        for (final feature in features)
          ModeCard(
            title: feature.title,
            icon: feature.icon,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => feature.widget)),
          ),
        ModeCard(
          title: 'History',
          icon: Icons.history,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HistoryPage())),
        ),
        ModeCard(
          title: 'Settings',
          icon: Icons.settings,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
        ModeCard(
          title: 'About',
          icon: Icons.info_outline,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),
      ],
    ),
  );
}

typedef Feature = ({String title, IconData icon, Widget widget});
