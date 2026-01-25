import 'package:daily_manna/models/scripture_range_ref.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/verse_selection/books_tab.dart';
import 'package:daily_manna/ui/verse_selection/recents_tab.dart';
import 'package:daily_manna/ui/verse_selection/review_tab.dart';
import 'package:flutter/material.dart';

/// Full-screen verse selection page with tabs for Books, Needs Review, and Recents.
class VerseSelectionPage extends StatelessWidget {
  const VerseSelectionPage({super.key, this.rangeMode = false});

  final bool rangeMode;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: rangeMode ? 1 : 3,
    child: AppScaffold(
      title: 'Select Verse',
      showShareButton: false,
      bottom: rangeMode
          ? null
          : const TabBar(
              tabs: [
                Tab(text: 'Books'),
                Tab(text: 'Review'),
                Tab(text: 'Recents'),
              ],
            ),
      body: rangeMode ? _buildRangeModeBody(context) : _buildNormalBody(context),
    ),
  );

  Widget _buildRangeModeBody(BuildContext context) => BooksTab.range(
    onRangeSelected: (ScriptureRangeRef ref) => Navigator.of(context).pop(ref),
  );

  Widget _buildNormalBody(BuildContext context) => TabBarView(
    children: [
      BooksTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
      ReviewTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
      RecentsTab(onVerseSelected: (ref) => _selectVerse(context, ref)),
    ],
  );

  void _selectVerse(BuildContext context, ScriptureRef ref) {
    Navigator.of(context).pop(ref);
  }
}
