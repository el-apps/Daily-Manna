import 'package:daily_manna/about_page.dart';
import 'package:daily_manna/home_page.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/settings_page.dart';
import 'package:daily_manna/ui/history/history_page.dart';
import 'package:daily_manna/ui/memorization/verse_memorization.dart';
import 'package:daily_manna/ui/recitation/recitation_mode.dart';
import 'package:daily_manna/ui/study/study_notes_detail_page.dart';
import 'package:daily_manna/ui/study/study_notes_page.dart';
import 'package:daily_manna/ui/study/study_result_detail_page.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
    GoRoute(path: '/study-notes', builder: (_, __) => const StudyNotesPage()),
    GoRoute(
      path: '/study-notes/:noteId',
      builder: (context, state) {
        final note = state.extra;
        if (note is db.StudyNote) return StudyNotesDetailPage(note: note);
        final id = int.tryParse(state.pathParameters['noteId'] ?? '');
        return StreamBuilder<db.StudyNote?>(
          stream: id == null
              ? Stream.value(null)
              : context.read<StudyNotesService>().watchNote(id),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final loaded = snapshot.data;
            return loaded == null
                ? const _RouteUnavailablePage(
                    message: 'This study note is no longer available.',
                  )
                : StudyNotesDetailPage(note: loaded);
          },
        );
      },
    ),
    GoRoute(
      path: '/history/study/:resultId',
      builder: (context, state) {
        final result = state.extra;
        if (result is db.Result) return StudyResultDetailPage(result: result);
        final id = int.tryParse(state.pathParameters['resultId'] ?? '');
        final database = context.read<db.AppDatabase>();
        return StreamBuilder<db.Result?>(
          stream: id == null
              ? Stream.value(null)
              : (database.select(
                  database.results,
                )..where((result) => result.id.equals(id))).watchSingleOrNull(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final loaded = snapshot.data;
            return loaded == null
                ? const _RouteUnavailablePage(
                    message: 'This study result is no longer available.',
                  )
                : StudyResultDetailPage(result: loaded);
          },
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
