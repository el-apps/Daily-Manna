import 'package:daily_manna/services/score_display.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = 'v${info.version}');
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'About',
    showShareButton: false,
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _VersionSection(version: _version),
          const _GradesSection(),
          const _ContributorsSection(),
        ],
      ),
    ),
  );
}

class _VersionSection extends StatelessWidget {
  final String version;

  const _VersionSection({required this.version});

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text('Daily Manna', style: Theme.of(context).textTheme.titleLarge),
        if (version.isNotEmpty)
          Text(
            version,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    ),
  );
}

class _GradesSection extends StatelessWidget {
  const _GradesSection();

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text('Grades', style: Theme.of(context).textTheme.titleMedium),
        ...ScoreDisplay.grades.map(
          (grade) => _GradeRow(
            emoji: grade.emoji,
            label: grade.label,
            range: grade.range,
          ),
        ),
      ],
    ),
  );
}

class _GradeRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String? range;

  const _GradeRow({required this.emoji, required this.label, this.range});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        if (range != null)
          Text(
            range!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    ),
  );
}

class _ContributorsSection extends StatelessWidget {
  const _ContributorsSection();

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Text('Contributors', style: Theme.of(context).textTheme.titleMedium),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: [
              const TextSpan(text: 'Addison Emig ('),
              TextSpan(
                text: 'Kwila Development',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(Uri.parse('https://kwila.dev')),
              ),
              const TextSpan(text: ')'),
            ],
          ),
        ),
      ],
    ),
  );
}
