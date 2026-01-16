import 'package:daily_manna/mode_card.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Feature> features = const [
    (title: 'Memorize', icon: Icons.voice_chat, widget: VerseMemorization()),
    (title: 'Recite', icon: Icons.mic, widget: RecitationMode()),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Daily Manna')),
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
          for (final feature in features)
            ModeCard(
              title: feature.title,
              icon: feature.icon,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => feature.widget)),
            ),
          ModeCard(
            title: 'Settings',
            icon: Icons.settings,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          const ListTile(leading: Text('More features coming soon!')),
        ],
      ),
    );
}

typedef Feature = ({String title, IconData icon, Widget widget});
