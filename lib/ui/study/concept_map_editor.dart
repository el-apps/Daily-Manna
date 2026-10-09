import 'dart:math' as math;

import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Map<String, Offset> conceptMapLayout(
  ConceptMapDocument document, {
  Map<String, Size> nodeSizes = const {},
}) {
  final nodeIds = document.nodes.map((node) => node.id).toSet();
  final ranks = <String, int>{};
  int rank(String id, Set<String> ancestors) {
    if (ranks.containsKey(id)) return ranks[id]!;
    var result = 0;
    for (final edge in document.edges.where((edge) => edge.to == id)) {
      // Back edges remain visible, but cannot increase ranks indefinitely.
      if (!nodeIds.contains(edge.from) || ancestors.contains(edge.from)) {
        continue;
      }
      result = math.max(
        result,
        rank(edge.from, {...ancestors, edge.from}) + edge.length,
      );
    }
    return ranks[id] = result;
  }

  for (final node in document.nodes) {
    rank(node.id, {node.id});
  }
  final groups = <int, List<ConceptMapNode>>{};
  for (final node in document.nodes) {
    groups.putIfAbsent(ranks[node.id] ?? 0, () => []).add(node);
  }
  final positions = <String, Offset>{};
  double height(String id) => nodeSizes[id]?.height ?? 90;
  final baseline =
      80 +
      document.nodes.fold<double>(
            0,
            (h, node) => math.max(h, height(node.id)),
          ) /
          2;
  final columns = groups.keys.toList()..sort();
  for (final column in columns) {
    final preferredCenters = <String, double>{};
    for (final node in groups[column]!) {
      final neighbors = <String>{
        for (final edge in document.edges)
          if (edge.from == node.id && positions.containsKey(edge.to)) edge.to,
        for (final edge in document.edges)
          if (edge.to == node.id && positions.containsKey(edge.from)) edge.from,
      };
      if (neighbors.isNotEmpty) {
        preferredCenters[node.id] =
            neighbors.fold<double>(
              0,
              (sum, id) => sum + positions[id]!.dy + height(id) / 2,
            ) /
            neighbors.length;
      }
    }
    final nodes = groups[column]!.toList()
      ..sort((a, b) {
        final comparison = (preferredCenters[a.id] ?? baseline).compareTo(
          preferredCenters[b.id] ?? baseline,
        );
        return comparison != 0
            ? comparison
            : groups[column]!.indexOf(a).compareTo(groups[column]!.indexOf(b));
      });
    var y = 80.0;
    for (final node in nodes) {
      // Match connected card centers, leaving room when branches cannot align.
      y = math.max(
        y,
        (preferredCenters[node.id] ?? baseline) - height(node.id) / 2,
      );
      positions[node.id] = Offset(80 + column * 260, y);
      y += math.max(160, height(node.id) + 24);
    }
  }
  return positions;
}

class ConceptMapEditor extends StatefulWidget {
  const ConceptMapEditor({
    super.key,
    required this.document,
    required this.editing,
    required this.onChanged,
    this.selectedNodeId,
    this.onNodeSelected,
  });

  final ConceptMapDocument document;
  final bool editing;
  final String? selectedNodeId;
  final ValueChanged<String>? onNodeSelected;
  final ValueChanged<ConceptMapDocument> onChanged;

  @override
  State<ConceptMapEditor> createState() => ConceptMapEditorState();
}

class ConceptMapEditorState extends State<ConceptMapEditor> {
  String? _connectingFrom;
  final _nodeSizes = <String, Size>{};

  void addNode([ConceptMapNodeType type = ConceptMapNodeType.note]) {
    final id = widget.document.nextNodeId;
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
      final id = widget.document.nextNodeId;
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
    final positions = conceptMapLayout(widget.document, nodeSizes: _nodeSizes);
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: .25,
      maxScale: 4,
      child: SizedBox(
        width: positions.entries.fold<double>(
          900,
          (width, entry) => math.max(
            width,
            entry.value.dx + (_nodeSizes[entry.key]?.width ?? 210) + 80,
          ),
        ),
        height: positions.entries.fold<double>(
          700,
          (height, entry) => math.max(
            height,
            entry.value.dy + (_nodeSizes[entry.key]?.height ?? 90) + 80,
          ),
        ),
        child: CustomPaint(
          painter: _ConceptMapEdgesPainter(widget.document, Map.of(_nodeSizes)),
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
                  connecting: _connectingFrom != null,
                  selected:
                      widget.editing && widget.selectedNodeId == entry.key,
                  onTap: () => _selectNode(entry.key),
                  onLongPress: () => _showNodeMenu(entry.key),
                  onSizeChanged: _updateNodeSize,
                  onChanged: (node) =>
                      widget.onChanged(widget.document.updateNode(node)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateNodeSize(String id, Size size) {
    if (_nodeSizes[id] == size) return;
    setState(() => _nodeSizes[id] = size);
  }

  void _selectNode(String id) {
    if (!widget.editing) return;
    if (_connectingFrom == null) {
      widget.onNodeSelected?.call(id);
      return;
    }
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

  Future<void> _showNodeMenu(String id) async {
    if (!widget.editing || _connectingFrom != null) return;
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Delete box'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (shouldDelete == true && mounted) {
      widget.onChanged(widget.document.deleteNode(id));
    }
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
    required this.connecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSizeChanged,
    required this.onChanged,
  });

  final ConceptMapNode node;
  final Offset position;
  final bool editing;
  final bool connecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String id, Size size) onSizeChanged;
  final ValueChanged<ConceptMapNode> onChanged;

  @override
  State<_ConceptMapNodeWidget> createState() => _ConceptMapNodeWidgetState();
}

class _ConceptMapNodeWidgetState extends State<_ConceptMapNodeWidget> {
  late final TextEditingController _controller;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.size != null) {
        widget.onSizeChanged(widget.node.id, context.size!);
      }
    });
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
        onLongPress: widget.onLongPress,
        child: Card(
          color: color,
          shape: widget.selected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.primary, width: 2),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child:
                widget.node.type == ConceptMapNodeType.passage &&
                    !widget.connecting
                ? _PassageNodeContent(
                    node: widget.node,
                    bibleService: bibleService,
                    showContent: widget.node.showPassage,
                  )
                : widget.editing && !widget.connecting
                ? TextField(
                    controller: _controller,
                    maxLines: null,
                    onChanged: (value) =>
                        widget.onChanged(widget.node.copyWith(label: value)),
                    decoration: const InputDecoration(border: InputBorder.none),
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
  });

  final ConceptMapNode node;
  final BibleService bibleService;
  final bool showContent;

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
            Expanded(
              child: Text(
                passage == null
                    ? node.label
                    : bibleService.getRangeRefName(passage),
              ),
            ),
          ],
        ),
        if (showContent) ...[const Divider(), Text(content)],
      ],
    );
  }
}

class _ConceptMapEdgesPainter extends CustomPainter {
  const _ConceptMapEdgesPainter(this.document, this.nodeSizes);

  final ConceptMapDocument document;
  final Map<String, Size> nodeSizes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final positions = conceptMapLayout(document, nodeSizes: nodeSizes);
    for (final edge in document.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final fromSize = nodeSizes[edge.from] ?? const Size(210, 90);
      final toSize = nodeSizes[edge.to] ?? const Size(210, 90);
      final fromCenter = from + Offset(fromSize.width / 2, fromSize.height / 2);
      final toCenter = to + Offset(toSize.width / 2, toSize.height / 2);
      final start = _boundaryPoint(fromCenter, toCenter, fromSize);
      final end = _boundaryPoint(toCenter, fromCenter, toSize);
      final horizontal =
          (toCenter.dx - fromCenter.dx).abs() >=
          (toCenter.dy - fromCenter.dy).abs();
      final path = Path()..moveTo(start.dx, start.dy);
      if (horizontal) {
        final midpoint = (start.dx + end.dx) / 2;
        path.cubicTo(midpoint, start.dy, midpoint, end.dy, end.dx, end.dy);
      } else {
        final midpoint = (start.dy + end.dy) / 2;
        path.cubicTo(start.dx, midpoint, end.dx, midpoint, end.dx, end.dy);
      }
      canvas.drawPath(path, paint);
      _drawArrowhead(canvas, end, toCenter, paint.color);
    }
  }

  static Offset _boundaryPoint(Offset center, Offset target, Size size) {
    final delta = target - center;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return center + Offset(delta.dx.sign * size.width / 2, 0);
    }
    return center + Offset(0, delta.dy.sign * size.height / 2);
  }

  static void _drawArrowhead(
    Canvas canvas,
    Offset tip,
    Offset targetCenter,
    Color color,
  ) {
    final direction = (targetCenter - tip);
    if (direction.distance == 0) return;
    final unit = direction / direction.distance;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final base = tip - unit * 12;
    final arrow = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + perpendicular.dx * 6, base.dy + perpendicular.dy * 6)
      ..lineTo(base.dx - perpendicular.dx * 6, base.dy - perpendicular.dy * 6)
      ..close();
    canvas.drawPath(
      arrow,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ConceptMapEdgesPainter oldDelegate) =>
      oldDelegate.document != document || oldDelegate.nodeSizes != nodeSizes;
}
