import 'package:daily_manna/bible_service.dart';
import 'package:daily_manna/practice_result.dart';
import 'package:daily_manna/scripture_ref.dart';
import 'package:daily_manna/share_dialog.dart';
import 'package:daily_manna/verse_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:word_tools/word_tools.dart';

class VerseMemorization extends StatefulWidget {
  const VerseMemorization({super.key});

  @override
  State<VerseMemorization> createState() => _VerseMemorizationState();
}

class _VerseMemorizationState extends State<VerseMemorization> {
  ScriptureRef _ref = ScriptureRef();
  late TextEditingController _inputController;
  final FocusNode _inputFocusNode = FocusNode();
  String _input = '';
  Result _result = Result.unknown;
  double _score = 0;
  int _attempts = 0;
  // TODO: store these in the DB instead of in widget state
  final List<MemorizationResult> _results = [];

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Memorize'),
        actions: [
          IconButton(icon: Icon(Icons.share), onPressed: _shareResults),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              VerseSelector(ref: _ref, onSelected: _selectRef),
              if (_result != Result.unknown && bibleService.hasVerse(_ref))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.brown.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.brown),
                  ),
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
                        "Enter the verse here. Voice input is recommended!",
                  ),
                  onChanged: (String value) => setState(() => _input = value),
                ),
              if (_result != Result.unknown)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _result.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _result.color),
                  ),
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
                LinearProgressIndicator(value: _score),
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
    setState(() {
      _attempts += 1;
      _score = compareWordSequences(actualVerse, _input);
      _result = _score >= 0.6 ? Result.correct : Result.incorrect;
      if (_result == Result.correct) {
        _results.add(
          MemorizationResult(ref: _ref, attempts: _attempts, score: _score),
        );
      }
    });
  }

  void _shareResults() => showDialog(
    context: context,
    builder: (_) => ShareDialog(memorizationResults: _results),
  );
}

enum Result {
  unknown(color: Colors.brown),
  learn(color: Colors.blue),
  incorrect(color: Colors.red),
  correct(color: Colors.green);

  final Color color;

  const Result({required this.color});
}
