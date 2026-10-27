import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/services/reading_reference_parser.dart';
import 'package:daily_manna/services/results_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class LogReadingPage extends StatefulWidget {
  const LogReadingPage({super.key});

  @override
  State<LogReadingPage> createState() => _LogReadingPageState();
}

class _LogReadingPageState extends State<LogReadingPage> {
  final _input = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bible = context.read<BibleService>();
    var passages = <ReadingPassage>[];
    String? parseError;
    try {
      passages = ReadingReferenceParser(bible).parse(_input.text);
    } on FormatException catch (error) {
      parseError = error.message;
    }
    return AppScaffold(
      title: 'Log reading',
      showShareButton: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Today', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 20),
              TextField(
                controller: _input,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'What did you read?',
                  hintText: 'e.g. Deut 1–4',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() => _saveError = null),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chapters, verses, or several passages separated by commas.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final example in ['Deut 1–4', 'John 1,3', '1 jhn 2'])
                    ActionChip(
                      label: Text(example),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _input.text = example;
                              _saveError = null;
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passages.isEmpty ? 'Preview' : 'Ready to log',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (parseError != null)
                      Text(
                        parseError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    else if (passages.isEmpty)
                      const Text(
                        'Enter a reference to see what will be logged.',
                      )
                    else
                      for (final passage in passages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            bible.getReadingName(
                              bookId: passage.bookId,
                              startChapter: passage.startChapter,
                              startVerse: passage.startVerse,
                              endChapter: passage.endChapter,
                              endVerse: passage.endVerse,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving || passages.isEmpty
                    ? null
                    : () => _save(passages),
                child: Text(_saving ? 'Logging…' : 'Log reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(List<ReadingPassage> passages) async {
    setState(() => _saving = true);
    try {
      await context.read<ResultsService>().addReading(passages);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reading logged')));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Could not log the reading. Your reference is still here; try again.';
      });
    }
  }
}
