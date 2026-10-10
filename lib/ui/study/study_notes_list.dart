import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/database/database.dart' as db;
import 'package:daily_manna/services/study_notes_service.dart';
import 'package:daily_manna/ui/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class StudyNotesList extends StatelessWidget {
  const StudyNotesList({
    super.key,
    required this.notes,
    required this.titleQuery,
    required this.passage,
  });

  final List<db.StudyNote> notes;
  final String titleQuery;
  final ScriptureRangeRef? passage;

  @override
  Widget build(BuildContext context) {
    final service = context.read<StudyNotesService>();
    final bibleService = context.read<BibleService>();
    final query = titleQuery.trim().toLowerCase();
    final filtered = notes.where((note) {
      final titleMatches =
          query.isEmpty || note.title.toLowerCase().contains(query);
      final passageMatches =
          passage == null ||
          service
              .passagesFor(note)
              .any((reference) => reference.overlaps(passage!));
      return titleMatches && passageMatches;
    }).toList();

    if (filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        message: 'No study notes found',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final note = filtered[index];
        final references = service.passagesFor(note);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(note.title),
            subtitle: Text(
              references.isEmpty
                  ? 'No passages yet'
                  : references
                        .map(
                          (reference) =>
                              bibleService.getRangeRefName(reference),
                        )
                        .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/study-notes/${note.id}', extra: note),
          ),
        );
      },
    );
  }
}
