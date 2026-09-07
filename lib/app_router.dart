import 'package:daily_manna/about_page.dart';
import 'package:daily_manna/home_page.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/history/history_page.dart';
import 'package:daily_manna/ui/interact/interact_page.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/interact', builder: (_, __) => const InteractPage()),
    GoRoute(
      path: '/select',
      pageBuilder: (_, state) => NoTransitionPage(
        key: state.pageKey,
        child: VerseSelectionPage(
          rangeMode: state.uri.queryParameters['mode'] == 'range',
        ),
      ),
    ),
    GoRoute(
      path: '/select/books',
      pageBuilder: (_, state) => NoTransitionPage(
        key: state.pageKey,
        child: VerseSelectionPage(
          rangeMode: state.uri.queryParameters['mode'] == 'range',
        ),
      ),
    ),
    GoRoute(
      path: '/select/books/:bookId',
      pageBuilder: (_, state) => NoTransitionPage(
        key: state.pageKey,
        child: VerseSelectionPage(
          rangeMode: state.uri.queryParameters['mode'] == 'range',
          initialBookId: state.pathParameters['bookId'],
        ),
      ),
    ),
    GoRoute(
      path: '/select/review',
      pageBuilder: (_, state) => NoTransitionPage(
        key: state.pageKey,
        child: VerseSelectionPage(
          rangeMode: state.uri.queryParameters['mode'] == 'range',
          initialTabIndex: 1,
        ),
      ),
    ),
    GoRoute(
      path: '/select/recents',
      pageBuilder: (_, state) => NoTransitionPage(
        key: state.pageKey,
        child: VerseSelectionPage(
          rangeMode: state.uri.queryParameters['mode'] == 'range',
          initialTabIndex: 2,
        ),
      ),
    ),
    GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
    GoRoute(
      path: '/history/study/:resultId',
      builder: (_, state) {
        final result = state.extra;
        return result is db.Result
            ? StudyNotesDetailPage(result: result)
            : const _RouteUnavailablePage(
                message: 'This study result is no longer available.',
              );
      },
    ),
    GoRoute(
      path: '/memorize',
      builder: (_, state) => VerseMemorization(
        initialRef: ScriptureRef(
          bookId: state.uri.queryParameters['book'],
          chapterNumber: int.tryParse(
            state.uri.queryParameters['chapter'] ?? '',
          ),
          verseNumber: int.tryParse(
            state.uri.queryParameters['startVerse'] ?? '',
          ),
        ),
      ),
    ),
    GoRoute(path: '/recite', builder: (_, __) => const RecitationMode()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
  ],
);

class _RouteUnavailablePage extends StatelessWidget {
  const _RouteUnavailablePage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(message)));
}
