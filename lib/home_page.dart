import 'package:daily_manna/mode_card.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _version = '';

  final List<Feature> features = const [
    (title: 'Memorize', icon: Icons.voice_chat, widget: VerseMemorization()),
    (title: 'Recite', icon: Icons.mic, widget: RecitationMode()),
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${info.version}';
    });
  }

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
        if (_version.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _version,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    ),
  );
}

typedef Feature = ({String title, IconData icon, Widget widget});
