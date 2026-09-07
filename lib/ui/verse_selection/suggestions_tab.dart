import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Suggestions based on recent passages and the next chapter in each book.
class SuggestionsTab extends StatelessWidget {
  final void Function(ScriptureRangeRef) onPassageSelected;

  const SuggestionsTab({super.key, required this.onPassageSelected});

  @override
  Widget build(BuildContext context) {
    final database = context.read<AppDatabase>();
    final bibleService = context.read<BibleService>();

    return FutureBuilder<List<_Suggestion>>(
      future: _getSuggestions(database, bibleService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suggestions = snapshot.data ?? [];
        if (suggestions.isEmpty) {
          return const EmptyState(
            icon: Icons.lightbulb_outline,
            message:
                'No suggestions yet.\nInteract with a passage to get started!',
          );
        }

        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              title: Text(bibleService.getRangeRefName(suggestion.ref)),
              subtitle: Text(suggestion.description),
              onTap: () => onPassageSelected(suggestion.ref),
            );
          },
        );
      },
    );
  }

  Future<List<_Suggestion>> _getSuggestions(
    AppDatabase database,
    BibleService bibleService,
  ) async {
    final results = await database.getAllResults();
    final suggestions = <_Suggestion>[];
    final studyPassages = <ScriptureRangeRef>[];
    final seen = <String>{};

    for (final result in results) {
      final ref = ScriptureRangeRef(
        bookId: result.bookId,
        chapter: result.startChapter,
        startVerse: result.startVerse,
        endVerse: result.endVerse,
      );
      final key = _key(ref);
      if (seen.add(key)) {
        suggestions.add(_Suggestion(ref, 'Recently interacted'));
        if (result.type == ResultType.study) {
          studyPassages.add(ref);
        }
        if (suggestions.length == 10) break;
      }
    }

    final nextChapterSuggestions = <_Suggestion>[];
    for (final passage in studyPassages) {
      final chapters = bibleService.getChapters(passage.bookId);
      final nextIndex =
          chapters.indexWhere((chapter) => chapter.num == passage.chapter) + 1;
      if (nextIndex <= 0 || nextIndex >= chapters.length) continue;

      final nextChapter = chapters[nextIndex];
      final nextRef = ScriptureRangeRef(
        bookId: passage.bookId,
        chapter: nextChapter.num,
        startVerse: nextChapter.verses.first.num,
        endVerse: nextChapter.verses.last.num,
      );
      if (seen.add(_key(nextRef))) {
        nextChapterSuggestions.add(_Suggestion(nextRef, 'Next chapter'));
      }
    }

    return [...nextChapterSuggestions, ...suggestions];
  }

  String _key(ScriptureRangeRef ref) =>
      '${ref.bookId}:${ref.chapter}:${ref.startVerse}:${ref.endVerse}';
}

class _Suggestion {
  final ScriptureRangeRef ref;
  final String description;

  const _Suggestion(this.ref, this.description);
}
