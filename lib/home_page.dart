import 'package:daily_manna/about_page.dart';
import 'package:daily_manna/mode_card.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/history/history_page.dart';
import 'package:daily_manna/ui/practice/practice_page.dart';
import 'package:daily_manna/ui/review/review_card.dart';
import 'package:daily_manna/ui/streak/streak_card.dart';
import 'package:daily_manna/ui/study/study_log_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
        const StreakCard(),
        ModeCard(
          title: 'Practice',
          icon: Icons.play_arrow,
          onTap: () => _navigateTo(context, const PracticePage()),
        ),
        const ReviewCard(),
        ModeCard(
          title: 'Study Log',
          icon: Icons.menu_book,
          onTap: () => _navigateTo(context, const StudyLogPage()),
        ),
        ModeCard(
          title: 'History',
          icon: Icons.history,
          onTap: () => _navigateTo(context, const HistoryPage()),
        ),
        ModeCard(
          title: 'Settings',
          icon: Icons.settings,
          onTap: () => _navigateTo(context, const SettingsPage()),
        ),
        ModeCard(
          title: 'About',
          icon: Icons.info_outline,
          onTap: () => _navigateTo(context, const AboutPage()),
        ),
      ],
    ),
  );
}
