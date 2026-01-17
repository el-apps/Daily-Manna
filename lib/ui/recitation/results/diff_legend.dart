import 'package:flutter/material.dart';
import 'package:word_tools/word_tools.dart';
import 'diff_colors.dart';

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
          color: DiffStatus.correct.primaryColor,
          label: 'Correct',
          isVisible: visibleStatuses.contains(DiffStatus.correct),
          onTap: () => onToggle(DiffStatus.correct),
        ),
        _LegendColor(
          color: DiffStatus.missing.primaryColor,
          label: 'Missing',
          isVisible: visibleStatuses.contains(DiffStatus.missing),
          onTap: () => onToggle(DiffStatus.missing),
        ),
        _LegendColor(
          color: DiffStatus.extra.primaryColor,
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
