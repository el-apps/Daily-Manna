import 'dart:math' as math;

import 'package:daily_manna/models/concept_map.dart';
import 'package:daily_manna/services/bible_service.dart';
import 'package:daily_manna/ui/verse_selection/verse_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _cardWidth = 300.0;

Map<String, Offset> conceptMapLayout(
  ConceptMapDocument document, {
  Map<String, Size> nodeSizes = const {},
}) {
  final nodeIds = document.nodes.map((node) => node.id).toSet();
  final neighbors = {for (final id in nodeIds) id: <String, int>{}};
  for (final edge in document.edges) {
    if (!nodeIds.contains(edge.from) || !nodeIds.contains(edge.to)) continue;
    for (final (a, b) in [(edge.from, edge.to), (edge.to, edge.from)]) {
      neighbors[a]![b] = math.min(neighbors[a]![b] ?? edge.length, edge.length);
    }
  }
  final ranks = <String, int>{
    for (final node in document.nodes)
      if (node.type == ConceptMapNodeType.keyPoint) node.id: 0,
  };
  final remaining = nodeIds.toSet();
  while (remaining.isNotEmpty) {
    final reachable = remaining.where(ranks.containsKey).toList();
    if (reachable.isEmpty) {
      // Without a key point, anchor this component at its most connected card.
      final root = remaining.reduce(
        (a, b) => neighbors[b]!.length > neighbors[a]!.length ? b : a,
      );
      ranks[root] = 0;
      reachable.add(root);
    }
    final current = reachable.reduce((a, b) => ranks[b]! < ranks[a]! ? b : a);
    remaining.remove(current);
    for (final id in remaining) {
      final length = neighbors[current]![id];
      if (length == null) continue;
      final distance = ranks[current]! + length;
      ranks[id] = math.min(ranks[id] ?? distance, distance);
    }
  }
  final groups = <int, List<ConceptMapNode>>{};
  for (final node in document.nodes) {
    groups.putIfAbsent(ranks[node.id] ?? 0, () => []).add(node);
  }
  final positions = <String, Offset>{};
  double height(String id) => nodeSizes[id]?.height ?? 90;
  final children = <String, List<String>>{
    for (final node in document.nodes)
      node.id: [
        for (final candidate in document.nodes)
          if (ranks[candidate.id]! > ranks[node.id]! &&
              neighbors[node.id]!.containsKey(candidate.id))
            candidate.id,
      ],
  };
  final spans = <String, double>{};
  late double Function(String) span;
  double childrenSpan(String id) {
    final list = children[id]!;
    return list.isEmpty
        ? 0
        : list
                  .take(list.length - 1)
                  .fold<double>(
                    0,
                    (sum, child) => sum + math.max(160, span(child) + 24),
                  ) +
              span(list.last);
  }

  span = (id) =>
      spans.putIfAbsent(id, () => math.max(height(id), childrenSpan(id)));
  final columns = groups.keys.toList()..sort();
  for (final column in columns) {
    final preferredCenters = <String, double>{};
    for (final node in groups[column]!) {
      final placedNeighbors = [
        for (final id in nodeIds)
          if (neighbors[node.id]!.containsKey(id) && positions.containsKey(id))
            id,
      ];
      if (placedNeighbors.isNotEmpty) {
        preferredCenters[node.id] =
            placedNeighbors.fold<double>(0, (sum, id) {
              var center =
                  positions[id]!.dy + height(id) / 2 - childrenSpan(id) / 2;
              for (final child in children[id]!) {
                if (child == node.id) return sum + center + span(child) / 2;
                center += math.max(160, span(child) + 24);
              }
              return sum + positions[id]!.dy + height(id) / 2;
            }) /
            placedNeighbors.length;
      }
    }
    final nodes = groups[column]!.toList()
      ..sort((a, b) {
        final comparison = (preferredCenters[a.id] ?? 0).compareTo(
          preferredCenters[b.id] ?? 0,
        );
        return comparison != 0
            ? comparison
            : groups[column]!.indexOf(a).compareTo(groups[column]!.indexOf(b));
      });
    var y = 80.0;
    for (final node in nodes) {
      final bandHeight = span(node.id);
      final preferred = preferredCenters[node.id];
      if (preferred != null) y = math.max(y, preferred - bandHeight / 2);
      positions[node.id] = Offset(
        80 + column * (_cardWidth + 50),
        y + (bandHeight - height(node.id)) / 2,
      );
      y += math.max(160, bandHeight + 24);
    }
  }
  // A crowded destination column may have pushed a card below its source.
  // Move sources to match, within the free space between their neighbors.
  for (final column in columns.reversed) {
    final nodes = groups[column]!.toList()
      ..sort((a, b) => positions[a.id]!.dy.compareTo(positions[b.id]!.dy));
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final targets = children[node.id]!;
      if (targets.isEmpty) continue;
      final top = targets
          .map((id) => positions[id]!.dy + height(id) / 2 - span(id) / 2)
          .reduce(math.min);
      final bottom = targets
          .map((id) => positions[id]!.dy + height(id) / 2 + span(id) / 2)
          .reduce(math.max);
      final center = (top + bottom) / 2;
      final minimum = i == 0
          ? 80.0
          : positions[nodes[i - 1].id]!.dy +
                math.max(160, height(nodes[i - 1].id) + 24);
      final maximum = i == nodes.length - 1
          ? double.infinity
          : positions[nodes[i + 1].id]!.dy -
                math.max(160, height(node.id) + 24);
      positions[node.id] = Offset(
        positions[node.id]!.dx,
        (center - height(node.id) / 2).clamp(minimum, maximum),
      );
    }
  }
  return positions;
}

List<Offset> conceptMapConnector(
  ConceptMapEdge edge,
  Map<String, Offset> positions,
  Map<String, Size> nodeSizes,
) {
  final cards = {
    for (final entry in positions.entries)
      entry.key:
          entry.value & (nodeSizes[entry.key] ?? const Size(_cardWidth, 90)),
  };
  // Route from a stable endpoint so equal-cost detours do not depend on tap order.
  final reversed = edge.from.compareTo(edge.to) > 0;
  final from = cards[reversed ? edge.to : edge.from];
  final to = cards[reversed ? edge.from : edge.to];
  if (from == null || to == null) return [];
  const clearance = 8.0;
  final horizontal = from.center.dx != to.center.dx;
  final direction = horizontal
      ? Offset((to.center.dx - from.center.dx).sign, 0)
      : Offset(0, (to.center.dy - from.center.dy).sign);
  final start =
      from.center + direction * (horizontal ? from.width / 2 : from.height / 2);
  final end =
      to.center - direction * (horizontal ? to.width / 2 : to.height / 2);
  final entry = start + direction * clearance;
  final exit = end - direction * clearance;
  final obstacles = cards.values
      .map((rect) => rect.inflate(clearance))
      .toList();
  final xs = {
    entry.dx,
    exit.dx,
    for (final rect in obstacles) ...[rect.left, rect.right],
  }.toList()..sort();
  final ys = {
    entry.dy,
    exit.dy,
    for (final rect in obstacles) ...[rect.top, rect.bottom],
  }.toList()..sort();
  bool blocked(Offset a, Offset b) => obstacles.any(
    (rect) => a.dy == b.dy
        ? a.dy > rect.top &&
              a.dy < rect.bottom &&
              math.max(a.dx, b.dx) > rect.left &&
              math.min(a.dx, b.dx) < rect.right
        : a.dx > rect.left &&
              a.dx < rect.right &&
              math.max(a.dy, b.dy) > rect.top &&
              math.min(a.dy, b.dy) < rect.bottom,
  );
  double distance(Offset a, Offset b) =>
      (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
  final costs = <Offset, double>{entry: 0};
  final previous = <Offset, Offset>{};
  final open = [entry];
  final visited = <Offset>{};
  while (open.isNotEmpty) {
    open.sort(
      (a, b) => (costs[b]! + distance(b, exit)).compareTo(
        costs[a]! + distance(a, exit),
      ),
    );
    final current = open.removeLast();
    if (current == exit) {
      final route = [exit];
      while (previous.containsKey(route.last)) {
        route.add(previous[route.last]!);
      }
      final points = [start, ...route.reversed, end];
      return reversed ? points.reversed.toList() : points;
    }
    visited.add(current);
    final x = xs.indexOf(current.dx);
    final y = ys.indexOf(current.dy);
    for (final next in [
      if (x > 0) Offset(xs[x - 1], current.dy),
      if (x + 1 < xs.length) Offset(xs[x + 1], current.dy),
      if (y > 0) Offset(current.dx, ys[y - 1]),
      if (y + 1 < ys.length) Offset(current.dx, ys[y + 1]),
    ]) {
      if (visited.contains(next) || blocked(current, next)) continue;
      final cost = costs[current]! + distance(current, next);
      if (cost >= (costs[next] ?? double.infinity)) continue;
      costs[next] = cost;
      previous[next] = current;
      if (!open.contains(next)) open.add(next);
    }
  }
  // Do not draw a connection if there is no unobstructed route.
  return [];
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
  final _viewportKey = GlobalKey();
  final _transform = TransformationController();
  String? _pendingCenterId;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

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
    if (!widget.editing || widget.selectedNodeId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _connectingFrom = widget.selectedNodeId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tap another card to connect it.')),
    );
  }

  Future<void> disconnectMenu() async {
    final selected = widget.selectedNodeId;
    if (!widget.editing || selected == null) return;
    setState(() => _connectingFrom = null);
    final neighbors = <String>{
      for (final edge in widget.document.edges)
        if (edge.from == selected) edge.to,
      for (final edge in widget.document.edges)
        if (edge.to == selected) edge.from,
    };
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Remove connection')),
            for (final node in widget.document.nodes)
              if (neighbors.contains(node.id))
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: Text(
                    node.passage == null
                        ? node.label
                        : context.read<BibleService>().getRangeRefName(
                            node.passage!,
                          ),
                  ),
                  onTap: () => Navigator.pop(context, node.id),
                ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    widget.onChanged(
      ConceptMapDocument(
        nodes: widget.document.nodes,
        edges: widget.document.edges
            .where(
              (edge) =>
                  !(edge.from == selected && edge.to == target ||
                      edge.from == target && edge.to == selected),
            )
            .toList(),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ConceptMapEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing) _connectingFrom = null;
    final previousIds = oldWidget.document.nodes.map((node) => node.id).toSet();
    for (final node in widget.document.nodes) {
      if (!previousIds.contains(node.id)) _pendingCenterId = node.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = conceptMapLayout(widget.document, nodeSizes: _nodeSizes);
    if (_pendingCenterId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final id = _pendingCenterId;
        final cardSize = _nodeSizes[id];
        final position = positions[id];
        final viewport = _viewportKey.currentContext?.size;
        if (cardSize == null || position == null || viewport == null) return;
        final center =
            position + Offset(cardSize.width / 2, cardSize.height / 2);
        final scale = _transform.value.getMaxScaleOnAxis();
        _pendingCenterId = null;
        _transform.value = Matrix4.diagonal3Values(scale, scale, scale)
          ..setTranslationRaw(
            viewport.width / 2 - center.dx * scale,
            viewport.height / 2 - center.dy * scale,
            0,
          );
      });
    }
    return InteractiveViewer(
      key: _viewportKey,
      transformationController: _transform,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: .25,
      maxScale: 4,
      child: SizedBox(
        width: positions.entries.fold<double>(
          900,
          (width, entry) => math.max(
            width,
            entry.value.dx + (_nodeSizes[entry.key]?.width ?? _cardWidth) + 80,
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
    if (_connectingFrom == id) return;
    widget.onChanged(
      widget.document.addEdge(ConceptMapEdge(from: _connectingFrom!, to: id)),
    );
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
      width: _cardWidth,
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
            child: widget.node.type == ConceptMapNodeType.passage
                ? _PassageNodeContent(
                    node: widget.node,
                    bibleService: bibleService,
                    showContent: widget.node.showPassage,
                  )
                : widget.editing
                ? TextField(
                    controller: _controller,
                    onTap: widget.onTap,
                    readOnly: widget.connecting,
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
      final points = conceptMapConnector(edge, positions, nodeSizes);
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConceptMapEdgesPainter oldDelegate) =>
      oldDelegate.document != document || oldDelegate.nodeSizes != nodeSizes;
}
