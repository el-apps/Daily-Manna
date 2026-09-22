import 'dart:math' as math;

import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Map<String, Offset> conceptMapLayout(ConceptMapDocument document) {
  final ranks = <String, int>{for (final node in document.nodes) node.id: 0};
  for (var pass = 0; pass < document.nodes.length; pass++) {
    for (final edge in document.edges) {
      ranks[edge.to] = math.max(
        ranks[edge.to] ?? 0,
        (ranks[edge.from] ?? 0) + edge.length,
      );
    }
  }
  final groups = <int, List<ConceptMapNode>>{};
  for (final node in document.nodes) {
    groups.putIfAbsent(ranks[node.id] ?? 0, () => []).add(node);
  }
  return {
    for (final group in groups.entries)
      for (var index = 0; index < group.value.length; index++)
        group.value[index].id: Offset(80 + group.key * 260, 80 + index * 160),
  };
}

class ConceptMapEditor extends StatefulWidget {
  const ConceptMapEditor({
    super.key,
    required this.document,
    required this.editing,
    required this.onChanged,
  });

  final ConceptMapDocument document;
  final bool editing;
  final ValueChanged<ConceptMapDocument> onChanged;

  @override
  State<ConceptMapEditor> createState() => ConceptMapEditorState();
}

class ConceptMapEditorState extends State<ConceptMapEditor> {
  String? _connectingFrom;

  void addNode([ConceptMapNodeType type = ConceptMapNodeType.note]) {
    final id = 'node${widget.document.nodes.length + 1}';
    widget.onChanged(
      widget.document.addNode(
        ConceptMapNode(id: id, type: type, label: _labelFor(type)),
      ),
    );
  }

  Future<void> addNodeMenu() async {
    if (!widget.editing) return;
    final type = await showModalBottomSheet<ConceptMapNodeType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final nodeType in ConceptMapNodeType.values)
              ListTile(
                leading: Icon(_iconFor(nodeType)),
                title: Text(_labelFor(nodeType)),
                onTap: () => Navigator.pop(context, nodeType),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    if (type == ConceptMapNodeType.passage) {
      final passage = await showPassageSelector(context);
      if (passage == null || !mounted) return;
      final bibleService = context.read<BibleService>();
      final id = 'node${widget.document.nodes.length + 1}';
      widget.onChanged(
        widget.document.addNode(
          ConceptMapNode(
            id: id,
            type: type,
            label: bibleService.getRangeRefName(passage),
            passage: passage,
          ),
        ),
      );
      return;
    }
    addNode(type);
  }

  void startConnecting() {
    if (!widget.editing) return;
    setState(() => _connectingFrom = 'pending');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap the first box, then the second box.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final positions = conceptMapLayout(widget.document);
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: .25,
      maxScale: 4,
      child: SizedBox(
        width: math.max(900, widget.document.nodes.length * 280.0),
        height: math.max(700, widget.document.nodes.length * 180.0),
        child: CustomPaint(
          painter: _ConceptMapEdgesPainter(widget.document),
          child: Stack(
            children: [
              for (final entry in positions.entries)
                _ConceptMapNodeWidget(
                  key: ValueKey(entry.key),
                  node: widget.document.nodes.firstWhere(
                    (node) => node.id == entry.key,
                  ),
                  position: entry.value,
                  editing: widget.editing,
                  onTap: () => _selectNode(entry.key),
                  onChanged: (node) =>
                      widget.onChanged(widget.document.updateNode(node)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectNode(String id) {
    if (!widget.editing || _connectingFrom == null) return;
    if (_connectingFrom == 'pending') {
      setState(() => _connectingFrom = id);
      return;
    }
    if (_connectingFrom != id) {
      widget.onChanged(
        widget.document.addEdge(ConceptMapEdge(from: _connectingFrom!, to: id)),
      );
    }
    setState(() => _connectingFrom = null);
  }

  static String _labelFor(ConceptMapNodeType type) => switch (type) {
    ConceptMapNodeType.keyPoint => 'Key point',
    ConceptMapNodeType.note => 'Note',
    ConceptMapNodeType.passage => 'Passage',
  };

  static IconData _iconFor(ConceptMapNodeType type) => switch (type) {
    ConceptMapNodeType.keyPoint => Icons.star_outline,
    ConceptMapNodeType.note => Icons.note_outlined,
    ConceptMapNodeType.passage => Icons.menu_book_outlined,
  };
}

class _ConceptMapNodeWidget extends StatefulWidget {
  const _ConceptMapNodeWidget({
    super.key,
    required this.node,
    required this.position,
    required this.editing,
    required this.onTap,
    required this.onChanged,
  });

  final ConceptMapNode node;
  final Offset position;
  final bool editing;
  final VoidCallback onTap;
  final ValueChanged<ConceptMapNode> onChanged;

  @override
  State<_ConceptMapNodeWidget> createState() => _ConceptMapNodeWidgetState();
}

class _ConceptMapNodeWidgetState extends State<_ConceptMapNodeWidget> {
  late final TextEditingController _controller;
  bool _showPassageContent = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.node.label);
  }

  @override
  void didUpdateWidget(covariant _ConceptMapNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.node.label &&
        oldWidget.node.label != widget.node.label) {
      _controller.text = widget.node.label;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bibleService = context.read<BibleService>();
    final color = switch (widget.node.type) {
      ConceptMapNodeType.keyPoint => colors.primaryContainer,
      ConceptMapNodeType.note => colors.secondaryContainer,
      ConceptMapNodeType.passage => colors.tertiaryContainer,
    };
    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      width: 210,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: widget.node.type == ConceptMapNodeType.passage
                ? _PassageNodeContent(
                    node: widget.node,
                    bibleService: bibleService,
                    showContent: _showPassageContent,
                    onToggleContent: () => setState(
                      () => _showPassageContent = !_showPassageContent,
                    ),
                  )
                : widget.editing
                ? TextField(
                    controller: _controller,
                    maxLines: null,
                    onChanged: (value) =>
                        widget.onChanged(widget.node.copyWith(label: value)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                  )
                : Text(widget.node.label),
          ),
        ),
      ),
    );
  }
}

class _PassageNodeContent extends StatelessWidget {
  const _PassageNodeContent({
    required this.node,
    required this.bibleService,
    required this.showContent,
    required this.onToggleContent,
  });

  final ConceptMapNode node;
  final BibleService bibleService;
  final bool showContent;
  final VoidCallback onToggleContent;

  @override
  Widget build(BuildContext context) {
    final passage = node.passage;
    final content = passage == null
        ? ''
        : bibleService.getPassageRange(
            passage.bookId,
            passage.chapter,
            passage.startVerse,
            endVerse: passage.endVerse,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(node.label)),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: showContent ? 'Show reference only' : 'Show passage',
              onPressed: onToggleContent,
              icon: Icon(showContent ? Icons.visibility_off : Icons.visibility),
            ),
          ],
        ),
        if (showContent) ...[
          const Divider(),
          Text(content),
        ],
      ],
    );
  }
}

class _ConceptMapEdgesPainter extends CustomPainter {
  const _ConceptMapEdgesPainter(this.document);

  final ConceptMapDocument document;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2;
    final positions = conceptMapLayout(document);
    for (final edge in document.edges) {
      final start = positions[edge.from];
      final end = positions[edge.to];
      if (start != null && end != null) {
        canvas.drawLine(
          start + const Offset(210, 45),
          end + const Offset(0, 45),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ConceptMapEdgesPainter oldDelegate) =>
      oldDelegate.document != document;
}
