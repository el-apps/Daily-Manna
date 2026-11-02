import 'dart:convert';

import 'package:daily_manna/services/study_notes_pdf.dart';
import 'package:daily_manna/ui/study/study_markdown_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF embeds Charter faces and a fallback for Unicode symbols', () async {
    final files = await buildStudyNotesPdfs(
      title: 'Typography',
      source: 'Regular **bold** *italic* ***bold italic*** →',
    );
    final pdf = latin1.decode(files.values.single);
    for (final font in [
      'CharterRegular',
      'CharterBold',
      'CharterItalic',
      'CharterBoldItalic',
      'DejaVuSerif',
    ]) {
      expect(
        RegExp('/FontName\\s*/$font(?=[\\s/<>])').hasMatch(pdf),
        isTrue,
        reason: 'The exported PDF must embed $font',
      );
    }
  });

  test('cut-and-stack splits files only for manual printing', () async {
    for (final format in [
      StudyNotesPdfFormat.cutAndStack,
      StudyNotesPdfFormat.cutAndStackDuplex,
    ]) {
      final files = await buildStudyNotesPdfs(
        title: 'Outline',
        source: 'First page\n\n\\newpage\n\nSecond page',
        format: format,
      );
      expect(
        files.keys,
        format == StudyNotesPdfFormat.cutAndStack
            ? ['Outline-fronts.pdf', 'Outline-backs.pdf']
            : ['Outline.pdf'],
      );
    }
  });

  test('PDF list paragraphs can span multiple pages', () async {
    final files = await buildStudyNotesPdfs(
      title: 'Long outline',
      source:
          '- Read ${List.filled(1000, 'a supporting **point**').join(' ')}\n'
          '  - A nested item\n\n'
          '    A continuation paragraph in the nested item.\n\n'
          '- The final item',
    );
    final pdf = latin1.decode(files.values.single);
    final pageCount = RegExp(
      r'/Type/Pages\b[^>]*?/Count\s+(\d+)',
    ).firstMatch(pdf)!;
    expect(int.parse(pageCount.group(1)!), greaterThan(1));
  });

  test('PDF quotes use compact insets without trailing blank lines', () async {
    final files = await buildStudyNotesPdfs(
      title: 'Quotations',
      // Twenty single-line quotes fit in the 504pt text area with the
      // script's insets; 7pt padding or trailing blank lines spill over.
      source: List.filled(20, '> A short quotation.').join('\n\n'),
    );
    final pdf = latin1.decode(files.values.single);
    final pageCount = RegExp(
      r'/Type/Pages\b[^>]*?/Count\s+(\d+)',
    ).firstMatch(pdf)!;
    expect(int.parse(pageCount.group(1)!), 1);
  });

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
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page labels count real breaks and reset when notes change', (
    tester,
  ) async {
    Future<void> preview(String source) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StudyMarkdownPreview(source: source)),
      ),
    );

    await preview('''
First page

```text
\\newpage
```

\\newpage

Second page

\\newpage

Third page
''');
    expect(find.text('Page 1/3'), findsNothing);
    expect(find.text('Page 2/3'), findsOneWidget);
    expect(find.text('Page 3/3'), findsOneWidget);

    await preview('First\n\n\\newpage\n\nSecond');
    expect(find.text('Page 2/2'), findsOneWidget);
    expect(find.text('Page 2/3'), findsNothing);

    await preview('Only one page');
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
