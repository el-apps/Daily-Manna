import 'package:markdown/markdown.dart' as md;

/// Sermon conventions shared by the screen preview and PDF renderer.
const studyBlockSyntaxes = <md.BlockSyntax>[
  _PageBreakSyntax(),
  _ReadParagraphSyntax(),
];

List<md.Node> parseStudyMarkdown(String source) => md.Document(
  blockSyntaxes: studyBlockSyntaxes,
  encodeHtml: false,
).parseLines(source.split('\n'));

class _PageBreakSyntax extends md.BlockSyntax {
  const _PageBreakSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\\newpage\s*$');

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    return md.Element.empty('pagebreak');
  }
}

class _ReadParagraphSyntax extends md.ParagraphSyntax {
  const _ReadParagraphSyntax();

  @override
  bool canParse(md.BlockParser parser) =>
      RegExp(r'^Read(?:\b|$)').hasMatch(parser.current.content);

  @override
  md.Node? parse(md.BlockParser parser) {
    final paragraph = super.parse(parser);
    // Setext headings are not reading cues.
    if (paragraph is! md.Element) return paragraph;
    return md.Element('read', paragraph.children);
  }
}
