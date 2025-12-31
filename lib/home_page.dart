import 'package:daily_manna/recitation_mode.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/verse_memorization.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  final List<Feature> features = const [
    (title: 'Memorize', icon: Icons.voice_chat, widget: VerseMemorization()),
    (title: 'Recite', icon: Icons.mic, widget: RecitationMode()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          for (final feature in features) FeatureCard(feature),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card.filled(
              child: ListTile(
                contentPadding: const EdgeInsetsGeometry.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                leading: const Text('Settings'),
                trailing: const Icon(Icons.settings),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ),
          ),
          const ListTile(leading: Text('More features coming soon!')),
        ],
      ),
    );
  }
}

typedef Feature = ({String title, IconData icon, Widget widget});

class FeatureCard extends StatelessWidget {
  const FeatureCard(this.feature, {super.key});

  final Feature feature;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Card.filled(
      child: ListTile(
        contentPadding: EdgeInsetsGeometry.symmetric(
          vertical: 16,
          horizontal: 24,
        ),
        leading: Text(
          feature.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        trailing: Icon(feature.icon),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => feature.widget)),
      ),
    ),
  );
}
