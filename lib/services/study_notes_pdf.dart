// pdf exposes page graphics but not the form/stream types needed for vector
// imposition. Keep these low-level imports confined to this exporter.
// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:daily_manna/models/study_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/format/array.dart';
import 'package:pdf/src/pdf/obj/formxobject.dart';
import 'package:pdf/src/pdf/obj/object_stream.dart';
import 'package:pdf/widgets.dart' as pw;

enum StudyNotesPdfFormat {
  sequential('Sequential'),
  opening('Opening'),
  cutAndStack('Cut-and-stack'),
  cutAndStackDuplex('Cut-and-stack Duplex');

  const StudyNotesPdfFormat(this.label);
  final String label;
}

/// Generates local PDFs, named for sharing, without a conversion service.
Future<Map<String, Uint8List>> buildStudyNotesPdfs({
  required String title,
  required String source,
  StudyNotesPdfFormat format = StudyNotesPdfFormat.sequential,
}) async {
  // Match the script's Bitstream Charter family, with a Unicode fallback for
  // symbols such as arrows that Charter does not contain. All fonts are local.
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/Charter.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Charter-Bold.ttf')),
    italic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Charter-Italic.ttf'),
    ),
    boldItalic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/Charter-BoldItalic.ttf'),
    ),
    fontFallback: [
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSerif.ttf')),
    ],
  );
  final document = pw.Document(title: title, theme: theme);
  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: const PdfPageFormat(396, 612, marginAll: 54),
        // extarticle's footer baseline sits 30 TeX points below the text
        // area. Paint it in the margin without reserving body-text space.
        buildForeground: (context) => pw.Align(
          alignment: pw.Alignment.bottomCenter,
          child: pw.Transform.translate(
            offset: const PdfPoint(0, -30 * 72 / 72.27),
            child: pw.Text(
              '${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ),
      ),
      maxPages: 1000,
      build: (_) => _blocks(parseStudyMarkdown(source), 8),
    ),
  );
  final name = title.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
  final basename = name.isEmpty ? 'study-notes' : name;
  // Saving paints and paginates the half-letter document before imposition.
  final sequential = await document.save();
  if (format == StudyNotesPdfFormat.sequential) {
    return {'$basename.pdf': sequential};
  }

  final pdf = document.document;
  final pages = pdf.pdfPageList.pages;
  // Reuse vector page contents and their resources, without rasterizing text.
  final halves = [
    for (final page in pages)
      PdfFormXObject(pdf)
        ..params['/BBox'] = PdfArray.fromNum([0, 0, 396, 612])
        ..params['/Resources'] = page.params['/Resources']!
        ..buf.putBytes([
          for (final content in page.contents.whereType<PdfObjectStream>())
            ...content.buf.output(),
        ]),
  ];
  pages.clear();
  void addSheet(int left, int right) {
    final page = PdfPage(pdf, pageFormat: const PdfPageFormat(792, 612));
    final canvas = page.getGraphics();
    if (left < halves.length) canvas.drawXObject(halves[left], 0, 0);
    if (right < halves.length) canvas.drawXObject(halves[right], 396, 0);
    // pdf 3.12's form names omit the slash required by resource dictionary keys.
    final forms = page.xObjects.values.toList();
    page.xObjects
      ..clear()
      ..addEntries(forms.map((form) => MapEntry('/${form.name}', form)));
  }

  if (format == StudyNotesPdfFormat.opening) {
    for (var i = 0; i < halves.length; i += 2) {
      addSheet(i, i + 1);
    }
    return {'$basename.pdf': await pdf.save()};
  }

  // Match the script: pad to four, then place the early pages on the right
  // strip and the later pages on the left. Backs assume short-edge duplex.
  final sheets = (halves.length + 3) ~/ 4;
  final half = sheets * 2;
  for (var i = 0; i < sheets; i++) {
    final early = i * 2;
    final late = early + half;
    addSheet(late, early);
    addSheet(early + 1, late + 1);
  }
  if (format == StudyNotesPdfFormat.cutAndStackDuplex) {
    return {'$basename.pdf': await pdf.save()};
  }

  final imposed = pages.toList();
  pages
    ..clear()
    ..addAll([for (var i = 0; i < imposed.length; i += 2) imposed[i]]);
  final fronts = await pdf.save();
  pages
    ..clear()
    ..addAll([for (var i = 1; i < imposed.length; i += 2) imposed[i]]);
  return {
    '$basename-fronts.pdf': fronts,
    '$basename-backs.pdf': await pdf.save(),
  };
}

List<pw.Widget> _blocks(List<md.Node> nodes, double size, {int depth = 0}) {
  final widgets = <pw.Widget>[];
  for (final node in nodes) {
    if (node is! md.Element) {
      if (node.textContent.trim().isNotEmpty) {
        widgets.add(pw.Text(node.textContent));
      }
      continue;
    }
    final children = node.children ?? <md.Node>[];
    switch (node.tag) {
      case 'pagebreak':
        widgets.add(pw.NewPage());
      case 'ul':
      case 'ol':
        var number = int.tryParse(node.attributes['start'] ?? '') ?? 1;
        final items = children.whereType<md.Element>().toList();
        // Leave enough room for the widest number so 9. and 10. share a
        // text column and multi-digit markers never wrap onto another line.
        final markerWidth = node.tag == 'ol'
            ? size * ((number + items.length - 1).toString().length * 0.6 + 0.8)
            : size * (depth == 0 ? 1.2 : 1.8);
        for (final item in items) {
          final parts = item.children ?? <md.Node>[];
          // Tight lists have inline children; loose lists have paragraphs.
          final blocks = <md.Node>[];
          var inline = <md.Node>[];
          void flush() {
            if (inline.isEmpty) return;
            blocks.add(md.Element('p', inline));
            inline = [];
          }

          for (final part in parts) {
            if (part is md.Element &&
                [
                  'p',
                  'read',
                  'ul',
                  'ol',
                  'blockquote',
                  'pagebreak',
                ].contains(part.tag)) {
              flush();
              blocks.add(part);
            } else {
              inline.add(part);
            }
          }
          flush();
          final itemWidgets = _blocks(blocks, size, depth: depth + 1);
          if (itemWidgets.isEmpty) continue;
          // Match the script's 1.2em outer and 1.8em nested list margins.
          // Spanning partitions keep the marker separate from the body while
          // allowing a long first paragraph to continue on the next page.
          widgets.add(
            pw.Partitions(
              children: [
                pw.Partition(
                  width: markerWidth,
                  child: pw.Padding(
                    padding: pw.EdgeInsets.only(right: size * 0.4),
                    child: pw.Text(
                      node.tag == 'ol' ? '${number++}.' : '•',
                      style: pw.TextStyle(fontSize: size),
                      textAlign: pw.TextAlign.right,
                      overflow: pw.TextOverflow.span,
                    ),
                  ),
                ),
                pw.Partition(
                  child: pw.Padding(
                    padding: pw.EdgeInsets.zero,
                    child: itemWidgets.first,
                  ),
                ),
              ],
            ),
          );
          widgets.addAll([
            for (final widget in itemWidgets.skip(1))
              pw.Padding(
                padding: pw.EdgeInsets.only(left: markerWidth),
                child: widget,
              ),
          ]);
        }
      case 'blockquote':
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 3),
            // Match the script's 0.6em horizontal and 0.4em vertical insets.
            padding: pw.EdgeInsets.symmetric(
              horizontal: size * 0.6,
              vertical: size * 0.4,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('009900')),
            ),
            // Keep the quote as spanning text, rather than a column that
            // cannot split a single long scripture paragraph across pages.
            child: pw.RichText(
              overflow: pw.TextOverflow.span,
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: size),
                children: _spans(children),
              ),
            ),
          ),
        );
      case 'hr':
        widgets.add(pw.Divider());
      default:
        final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
        final level = heading == null ? null : int.parse(heading.group(1)!);
        // The script uses extarticle at 8pt: Large=10.95pt, large=10pt,
        // normalsize=8pt. Match its nominal spacing (Charter's x-height is
        // 0.481em), without LaTeX's stretch/shrink page-layout adjustments.
        final ex = size * 0.481;
        final (fontSize, spaceBefore, spaceAfter) = switch (level) {
          1 => (10.95, 1.5 * ex, 2.3 * ex),
          2 => (10.0, 1.5 * ex, 1.5 * ex),
          3 => (size, 1.5 * ex, 1.5 * ex),
          4 => (size, 1.5 * ex, 0.8 * ex),
          5 => (size, 1.2 * ex, 0.6 * ex),
          6 => (size, 0.35 * 9.5, 4.0),
          _ => (size, 0.0, 4.0),
        };
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: widgets.isEmpty ? 0 : spaceBefore),
            child: pw.RichText(
              overflow: pw.TextOverflow.span,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: level == null
                      ? pw.FontWeight.normal
                      : pw.FontWeight.bold,
                  // LaTeX section commands are black; only the custom H6
                  // filter uses the script's blue textbf definition.
                  color: level == 6
                      ? PdfColor.fromHex('1565C0')
                      : node.tag == 'read'
                      ? PdfColor.fromHex('C00000')
                      : PdfColors.black,
                ),
                children: _spans(children),
              ),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: spaceAfter));
    }
  }
  return widgets;
}

List<pw.InlineSpan> _spans(List<md.Node> nodes) => [
  for (final (index, node) in nodes.indexed)
    if (node is md.Element)
      pw.TextSpan(
        text: node.tag == 'br' ? '\n' : null,
        style: switch (node.tag) {
          'strong' => pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('1565C0'),
          ),
          'em' => pw.TextStyle(fontStyle: pw.FontStyle.italic),
          'read' => pw.TextStyle(color: PdfColor.fromHex('C00000')),
          'code' => pw.TextStyle(font: pw.Font.courier()),
          'a' => const pw.TextStyle(
            color: PdfColors.blue,
            decoration: pw.TextDecoration.underline,
          ),
          _ => null,
        },
        children: [
          ..._spans(node.children ?? []),
          // Separate paragraphs without adding blank lines after the quote.
          if (index < nodes.length - 1 &&
              ['p', 'read', 'li'].contains(node.tag))
            const pw.TextSpan(text: '\n\n'),
        ],
      )
    else
      pw.TextSpan(text: node.textContent),
];
