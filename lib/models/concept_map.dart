import 'package:daily_manna/models/scripture_range_ref.dart';

enum ConceptMapNodeType { keyPoint, note, passage }

class ConceptMapNode {
  const ConceptMapNode({
    required this.id,
    required this.type,
    required this.label,
    this.passage,
  });

  final String id;
  final ConceptMapNodeType type;
  final String label;
  final ScriptureRangeRef? passage;

  ConceptMapNode copyWith({
    ConceptMapNodeType? type,
    String? label,
    ScriptureRangeRef? passage,
  }) => ConceptMapNode(
    id: id,
    type: type ?? this.type,
    label: label ?? this.label,
    passage: passage ?? this.passage,
  );
}

class ConceptMapEdge {
  const ConceptMapEdge({required this.from, required this.to, this.length = 1});

  final String from;
  final String to;
  final int length;
}

class ConceptMapDocument {
  const ConceptMapDocument({this.nodes = const [], this.edges = const []});

  final List<ConceptMapNode> nodes;
  final List<ConceptMapEdge> edges;

  factory ConceptMapDocument.fromMermaid(String source) {
    final nodes = <ConceptMapNode>[];
    final edges = <ConceptMapEdge>[];
    final nodePattern = RegExp(
      r'^\s*([A-Za-z][\w-]*)\[\[(.*?)\]\]|^\s*([A-Za-z][\w-]*)\[(.*?)\]',
    );
    final edgePattern = RegExp(r'([A-Za-z][\w-]*)\s*(-+)>\s*([A-Za-z][\w-]*)');
    for (final line in source.split('\n')) {
      final nodeMatch = nodePattern.firstMatch(line);
      if (nodeMatch != null) {
        final id = nodeMatch.group(1) ?? nodeMatch.group(3)!;
        final label = nodeMatch.group(2) ?? nodeMatch.group(4)!;
        final type = line.contains(':::keyPoint')
            ? ConceptMapNodeType.keyPoint
            : line.contains(':::passage')
            ? ConceptMapNodeType.passage
            : ConceptMapNodeType.note;
        nodes.add(ConceptMapNode(id: id, type: type, label: _unescape(label)));
      }
      final edgeMatch = edgePattern.firstMatch(line);
      if (edgeMatch != null) {
        edges.add(
          ConceptMapEdge(
            from: edgeMatch.group(1)!,
            to: edgeMatch.group(3)!,
            length: (edgeMatch.group(2)!.length - 2).clamp(1, 4),
          ),
        );
      }
    }
    return ConceptMapDocument(nodes: nodes, edges: edges);
  }

  String toMermaid() {
    final buffer = StringBuffer('flowchart TD\n');
    for (final node in nodes) {
      final className = switch (node.type) {
        ConceptMapNodeType.keyPoint => 'keyPoint',
        ConceptMapNodeType.note => 'note',
        ConceptMapNodeType.passage => 'passage',
      };
      buffer.writeln('  ${node.id}[${_escape(node.label)}]:::$className');
    }
    for (final edge in edges) {
      buffer.writeln('  ${edge.from} ${'-' * (edge.length + 2)}> ${edge.to}');
    }
    return buffer.toString().trimRight();
  }

  ConceptMapDocument addNode(ConceptMapNode node) =>
      ConceptMapDocument(nodes: [...nodes, node], edges: edges);

  ConceptMapDocument updateNode(ConceptMapNode node) => ConceptMapDocument(
    nodes: [for (final item in nodes) item.id == node.id ? node : item],
    edges: edges,
  );

  ConceptMapDocument addEdge(ConceptMapEdge edge) =>
      ConceptMapDocument(nodes: nodes, edges: [...edges, edge]);

  static String _escape(String value) => value.replaceAll(']', '#93;');
  static String _unescape(String value) => value.replaceAll('#93;', ']');
}
