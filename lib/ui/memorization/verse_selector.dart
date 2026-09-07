import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class VerseSelector extends StatelessWidget {
  const VerseSelector.range({
    super.key,
    required ScriptureRangeRef rangeRef,
    required void Function(ScriptureRangeRef) onRangeSelected,
  }) : _rangeRef = rangeRef,
       _onRangeSelected = onRangeSelected;

  final ScriptureRangeRef _rangeRef;
  final void Function(ScriptureRangeRef) _onRangeSelected;

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final displayText = _rangeRef.complete
        ? bibleService.getRangeRefName(_rangeRef)
        : 'Select passage';
    return ListTile(
      title: Text(displayText),
      trailing: Icon(Icons.chevron_right),
      onTap: () => _openSelectionPage(context),
    );
  }

  void _openSelectionPage(BuildContext context) async {
    final selectedRef = await context.push<ScriptureRangeRef>(
      '/select?mode=range',
    );
    if (selectedRef != null) {
      _onRangeSelected(selectedRef);
    }
  }
}
