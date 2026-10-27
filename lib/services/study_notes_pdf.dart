import 'dart:typed_data';

import 'package:daily_manna/models/study_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a local PDF without sending the note to a conversion service.
Future<Uint8List> buildStudyNotesPdf({
  required String title,
  required String source,
  bool halfLetter = false,
}) async {
  // Bundle fonts so export works offline and preserves curly quotes and arrows.
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSerif.ttf')),
    bold: pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSerif-Bold.ttf'),
    ),
    italic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSerif-Italic.ttf'),
    ),
    boldItalic: pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSerif-BoldItalic.ttf'),
    ),
  );
  final document = pw.Document(title: title, theme: theme);
  final format = halfLetter
      ? const PdfPageFormat(396, 612, marginAll: 54)
      : const PdfPageFormat(612, 792, marginAll: 72);
  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      maxPages: 1000,
      build: (_) => _blocks(parseStudyMarkdown(source), halfLetter ? 8 : 11),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
    ),
  );
  return document.save();
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
        for (final item in children.whereType<md.Element>()) {
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
          if (blocks.isNotEmpty && blocks.first is md.Element) {
            final first = blocks.first as md.Element;
            first.children?.insert(
              0,
              md.Text(node.tag == 'ol' ? '${number++}. ' : '• '),
            );
          }
          widgets.addAll(_blocks(blocks, size, depth: depth + 1));
        }
      case 'blockquote':
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 3),
            padding: const pw.EdgeInsets.all(7),
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
        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              left: depth > 0 ? (depth - 1) * size * 1.8 : 0,
            ),
            child: pw.RichText(
              overflow: pw.TextOverflow.span,
              text: pw.TextSpan(
                style: pw.TextStyle(
                  fontSize: level == null
                      ? size
                      : size * [1.8, 1.5, 1.2, 1, 1, 1][level - 1],
                  fontWeight: level == null
                      ? pw.FontWeight.normal
                      : pw.FontWeight.bold,
                  color: level != null
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
        widgets.add(pw.SizedBox(height: level == null ? 4 : 8));
    }
  }
  return widgets;
}

List<pw.InlineSpan> _spans(List<md.Node> nodes) => [
  for (final node in nodes)
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
          if (['p', 'read', 'li'].contains(node.tag))
            const pw.TextSpan(text: '\n\n'),
        ],
      )
    else
      pw.TextSpan(text: node.textContent),
];
