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
    builders: {'read': _ReadBuilder(), 'pagebreak': _PageBreakBuilder()},
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
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => const Row(
    children: [
      Expanded(child: Divider()),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('Page break'),
      ),
      Expanded(child: Divider()),
    ],
  );
}
