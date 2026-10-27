import 'package:daily_manna/ui/study/study_markdown_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sermon Markdown preserves nesting, emphasis and reading cues', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyMarkdownPreview(
              source: '''
# Outline

- Main point
  - Supporting **truth**
    - Read James 1:9 with **emphasis**

Read Jeremiah 9

Reader is not a reading cue

> A quotation

###### Sixth heading

\\newpage
''',
            ),
          ),
        ),
      ),
    );

    final supporting = find.text('Supporting truth', findRichText: true);
    final reading = find.text(
      'Read James 1:9 with emphasis',
      findRichText: true,
    );
    final main = find.text('Main point', findRichText: true);
    expect(
      tester.getTopLeft(supporting).dx,
      greaterThan(tester.getTopLeft(main).dx),
    );
    expect(
      tester.getTopLeft(reading).dx,
      greaterThan(tester.getTopLeft(supporting).dx),
    );

    final text = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.textSpan?.toPlainText() == 'Read Jeremiah 9',
      ),
    );
    expect(text.style?.color, const Color(0xFFC00000));
    final richText = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.textSpan?.toPlainText() == 'Read James 1:9 with emphasis',
      ),
    );
    final emphasis = richText.textSpan!.children!
        .whereType<TextSpan>()
        .singleWhere((s) => s.toPlainText() == 'emphasis');
    expect(emphasis.style?.color, const Color(0xFF1565C0));
    expect(emphasis.style?.fontWeight, FontWeight.bold);
    final ordinary = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            (w.data ?? w.textSpan?.toPlainText()) ==
                'Reader is not a reading cue',
      ),
    );
    expect(ordinary.style?.color, isNot(const Color(0xFFC00000)));
    expect(find.text('A quotation', findRichText: true), findsOneWidget);
    expect(find.text('Sixth heading', findRichText: true), findsOneWidget);
    expect(find.text('Page break'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
