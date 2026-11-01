import 'package:daily_manna/models/study_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class StudyMarkdownPreview extends StatelessWidget {
  const StudyMarkdownPreview({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: source,
    selectable: true,
    blockSyntaxes: studyBlockSyntaxes,
    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      strong: const TextStyle(
        color: Color(0xFF1565C0),
        fontWeight: FontWeight.bold,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF009900)),
      ),
      blockquotePadding: const EdgeInsets.all(10),
      listIndent: 20,
    ),
    builders: {
      'read': _ReadBuilder(),
      'pagebreak': _PageBreakBuilder(parseStudyMarkdown(source)),
    },
  );
}

class _ReadBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => SelectableText.rich(
    TextSpan(children: _spans(element.children ?? [])),
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFC00000)),
  );

  List<InlineSpan> _spans(List<md.Node> nodes) => [
    for (final node in nodes)
      if (node is md.Element)
        TextSpan(
          text: node.tag == 'br' ? '\n' : null,
          style: switch (node.tag) {
            'strong' => const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
            'em' => const TextStyle(fontStyle: FontStyle.italic),
            'code' => const TextStyle(fontFamily: 'monospace'),
            _ => null,
          },
          children: _spans(node.children ?? []),
        )
      else
        TextSpan(text: node.textContent),
  ];
}

class _PageBreakBuilder extends MarkdownElementBuilder {
  _PageBreakBuilder(List<md.Node> nodes) : totalPages = 1 + _countBreaks(nodes);

  final int totalPages;
  int page = 0;

  // Count parsed markers so fenced code containing \newpage stays ordinary text.
  static int _countBreaks(List<md.Node> nodes) => nodes.fold(
    0,
    (count, node) =>
        count +
        (node is md.Element
            ? (node.tag == 'pagebreak' ? 1 : _countBreaks(node.children ?? []))
            : 0),
  );

  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('Page ${++page}/$totalPages'),
      ),
      const Expanded(child: Divider()),
    ],
  );
}
