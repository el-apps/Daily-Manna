import 'package:flutter/material.dart';
import 'package:word_tools/word_tools.dart';
import 'package:daily_manna/ui/recitation/results/recitation_results.dart';

class DiffComparison extends StatefulWidget {
  final List<DiffWord> diff;

  const DiffComparison({super.key, required this.diff});

  @override
  State<DiffComparison> createState() => _DiffComparisonState();
}

class _DiffComparisonState extends State<DiffComparison> {
  final Set<DiffStatus> _visibleStatuses = {
    DiffStatus.correct,
    DiffStatus.missing,
    DiffStatus.extra,
  };

  void _toggleVisibility(DiffStatus status) {
    setState(() {
      if (_visibleStatuses.contains(status)) {
        _visibleStatuses.remove(status);
      } else {
        _visibleStatuses.add(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredDiff = widget.diff
        .where((word) => _visibleStatuses.contains(word.status))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        MinimalLegend(
          visibleStatuses: _visibleStatuses,
          onToggle: _toggleVisibility,
        ),
        DiffPassageSection(diff: filteredDiff),
      ],
    );
  }
}

class MinimalLegend extends StatelessWidget {
  final Set<DiffStatus> visibleStatuses;
  final Function(DiffStatus) onToggle;

  const MinimalLegend({
    super.key,
    required this.visibleStatuses,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        _LegendColor(
          color: _getPrimaryColor(DiffStatus.correct),
          label: 'Correct',
          isVisible: visibleStatuses.contains(DiffStatus.correct),
          onTap: () => onToggle(DiffStatus.correct),
        ),
        _LegendColor(
          color: _getPrimaryColor(DiffStatus.missing),
          label: 'Missing',
          isVisible: visibleStatuses.contains(DiffStatus.missing),
          onTap: () => onToggle(DiffStatus.missing),
        ),
        _LegendColor(
          color: _getPrimaryColor(DiffStatus.extra),
          label: 'Extra',
          isVisible: visibleStatuses.contains(DiffStatus.extra),
          onTap: () => onToggle(DiffStatus.extra),
        ),
      ],
    ),
  );
}

class _LegendColor extends StatelessWidget {
  final Color color;
  final String label;
  final bool isVisible;
  final VoidCallback onTap;

  const _LegendColor({
    required this.color,
    required this.label,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Opacity(
        opacity: isVisible ? 1.0 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isVisible
                    ? color.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
                border: Border.all(
                  color: isVisible ? color : Colors.grey,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

MaterialColor _getPrimaryColor(DiffStatus status) => switch (status) {
  DiffStatus.correct => Colors.green,
  DiffStatus.missing => Colors.red,
  DiffStatus.extra => Colors.yellow,
};
