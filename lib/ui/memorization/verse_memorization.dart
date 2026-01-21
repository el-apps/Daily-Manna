import 'package:daily_manna/models/score_data.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/memorization/practice_result.dart';
import 'package:daily_manna/ui/score_emoji.dart';
import 'package:daily_manna/models/scripture_ref.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:daily_manna/ui/memorization/verse_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:word_tools/word_tools.dart';

class VerseMemorization extends StatefulWidget {
  final ScriptureRef? initialRef;

  const VerseMemorization({super.key, this.initialRef});

  @override
  State<VerseMemorization> createState() => _VerseMemorizationState();
}

class _VerseMemorizationState extends State<VerseMemorization> {
  late ScriptureRef _ref;
  late TextEditingController _inputController;
  final FocusNode _inputFocusNode = FocusNode();
  String _input = '';
  Result _result = Result.unknown;
  double _score = 0;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _ref = widget.initialRef ?? const ScriptureRef();
    _inputController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    final bibleService = context.read<BibleService>();
    final actualVerse = bibleService.hasVerse(_ref)
        ? bibleService.getVerse(
            _ref.bookId!,
            _ref.chapterNumber!,
            _ref.verseNumber!,
          )
        : '';
    return AppScaffold(
      title: 'Memorize',
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              VerseSelector(ref: _ref, onSelected: _selectRef),
              if (_result != Result.unknown && bibleService.hasVerse(_ref))
                ThemeCard(
                  style: ThemeCardStyle.brown,
                  child: Text(
                    actualVerse,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              if (bibleService.hasVerse(_ref))
                TextFormField(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'Enter the verse here. Voice input is recommended!',
                  ),
                  onChanged: (String value) => setState(() => _input = value),
                ),
              if (_result != Result.unknown)
                ThemeCard(
                  style: _getThemeCardStyle(_result),
                  child: Text(switch (_result) {
                    Result.learn => 'Practice the verse...',
                    Result.incorrect => 'Try again',
                    Result.correct => 'Correct!',
                    // This case should never be reached
                    Result.unknown => '',
                  }, style: Theme.of(context).textTheme.bodyLarge),
                ),
              if (_result != Result.correct && _ref.complete)
                Row(
                  spacing: 8,
                  children: [
                    if (_input.isNotEmpty)
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _clearInput,
                          child: Text('Clear'),
                        ),
                      ),
                    if (_input.isEmpty && _attempts == 0)
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _viewVerse,
                          child: Text('View Verse'),
                        ),
                      ),
                    if (_input.isNotEmpty)
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _gradeSubmission(actualVerse),
                          child: Text('Submit'),
                        ),
                      ),
                  ],
                ),
              if (_result == Result.correct && _ref.complete) ...[
                Center(
                  child: ScoreEmoji(
                    score: ScoreData(value: _score, attempts: _attempts),
                    fontSize: 48,
                  ),
                ),
                FilledButton(
                  // TODO: go to the next verse in the user's queue
                  onPressed: () => _selectRef(
                    _ref.copyWith(verseNumber: _ref.verseNumber! + 1),
                  ),
                  child: Text('Next'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _selectRef(ScriptureRef ref) {
    setState(() {
      _ref = ref;
      _result = Result.unknown;
      _attempts = 0;
      _score = 0;
      _clearInput();
      // Focus the input field after we render the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.requestFocus();
      });
    });
  }

  void _clearInput() => setState(() {
    _inputController.clear();
    _input = '';
  });

  void _viewVerse() {
    setState(() {
      _attempts += 1;
      _result = Result.learn;
    });
  }

  void _gradeSubmission(String actualVerse) {
    if (kDebugMode) {
      print(actualVerse);
      print(_input);
    }
    _inputFocusNode.unfocus();
    final resultsService = context.read<ResultsService>();
    setState(() {
      _attempts += 1;
      _score = compareWordSequences(actualVerse, _input);
      _result = _score >= 0.6 ? Result.correct : Result.incorrect;
      if (_result == Result.correct) {
        final result = MemorizationResult(
          ref: _ref,
          attempts: _attempts,
          score: _score,
        );
        resultsService.addMemorizationResult(result);
      }
    });
  }

  ThemeCardStyle _getThemeCardStyle(Result result) {
    switch (result) {
      case Result.learn:
        return ThemeCardStyle.blue;
      case Result.incorrect:
        return ThemeCardStyle.red;
      case Result.correct:
        return ThemeCardStyle.green;
      case Result.unknown:
        return ThemeCardStyle.brown;
    }
  }
}

enum Result {
  unknown(color: Colors.brown),
  learn(color: Colors.blue),
  incorrect(color: Colors.red),
  correct(color: Colors.green);

  final Color color;

  const Result({required this.color});
}
