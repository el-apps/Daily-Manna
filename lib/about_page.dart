import 'package:daily_manna/services/score_display.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
        children: [
          _VersionSection(version: _version),
          const SizedBox(height: 16),
          const _GradesSection(),
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
      children: [
        Text('Daily Manna', style: Theme.of(context).textTheme.titleLarge),
        if (version.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            version,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
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
      children: [
        Text('Grades', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'We use growth-themed emoji to celebrate your memorization progress:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ...ScoreDisplay.grades.map(
          (grade) => _GradeRow(
            emoji: grade.emoji,
            label: grade.label,
            range: grade.range,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Every score represents growth in your journey with Scripture. Keep growing!',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.primary,
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
