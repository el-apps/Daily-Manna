import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerseSelector extends StatelessWidget {
  const VerseSelector({super.key, required this.ref, required this.onSelected});

  final ScriptureRef ref;
  final Function(ScriptureRef) onSelected;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    return ListTile(
      title: Text(ref.complete ? bibleService.getRefName(ref) : 'Select verse'),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _openSelectionPage(context),
    );
  }

  void _openSelectionPage(BuildContext context) async {
    final selectedRef = await Navigator.of(context).push<ScriptureRef>(
      MaterialPageRoute(builder: (_) => const VerseSelectionPage()),
    );

    if (selectedRef != null) {
      onSelected(selectedRef);
    }
  }
}
