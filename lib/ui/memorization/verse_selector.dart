import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerseSelector extends StatelessWidget {
  const VerseSelector({
    super.key,
    required ScriptureRef ref,
    required void Function(ScriptureRef) onSelected,
  }) : _ref = ref,
       _rangeRef = null,
       _onSelected = onSelected,
       _onRangeSelected = null;

  const VerseSelector.range({
    super.key,
    required ScriptureRangeRef rangeRef,
    required void Function(ScriptureRangeRef) onRangeSelected,
  }) : _rangeRef = rangeRef,
       _ref = null,
       _onRangeSelected = onRangeSelected,
       _onSelected = null;

  final ScriptureRef? _ref;
  final ScriptureRangeRef? _rangeRef;
  final void Function(ScriptureRef)? _onSelected;
  final void Function(ScriptureRangeRef)? _onRangeSelected;

  bool get _rangeMode => _onRangeSelected != null;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final String displayText;
    if (_rangeMode) {
      final rangeRef = _rangeRef!;
      displayText = rangeRef.complete
          ? bibleService.getRangeRefName(rangeRef)
          : 'Select passage';
    } else {
      final ref = _ref!;
      displayText = ref.complete
          ? bibleService.getRefName(ref)
          : 'Select verse';
    }
    return ListTile(
      title: Text(displayText),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _openSelectionPage(context),
    );
  }

  void _openSelectionPage(BuildContext context) async {
    if (_rangeMode) {
      final selectedRef = await Navigator.of(context).push<ScriptureRangeRef>(
        MaterialPageRoute(
          builder: (_) => const VerseSelectionPage(rangeMode: true),
        ),
      );
      if (selectedRef != null) {
        _onRangeSelected!(selectedRef);
      }
    } else {
      final selectedRef = await Navigator.of(context).push<ScriptureRef>(
        MaterialPageRoute(builder: (_) => const VerseSelectionPage()),
      );
      if (selectedRef != null) {
        _onSelected!(selectedRef);
      }
    }
  }
}
