import 'package:daily_manna/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

List<DateTime> buildMonths({
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final startMonth = DateTime(firstDate.year, firstDate.month);
  final endMonth = DateTime(lastDate.year, lastDate.month);

  final months = <DateTime>[];
  var current = endMonth;
  while (!current.isBefore(startMonth)) {
    months.add(current);
    current = DateTime(current.year, current.month - 1);
  }
  return months;
}

List<DateTime?> buildMonthCells(DateTime monthStart) {
  final leadingEmptyCells = monthStart.weekday % 7;
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  final trailingEmptyCells = (7 - ((leadingEmptyCells + daysInMonth) % 7)) % 7;

  return [
    ...List<DateTime?>.filled(leadingEmptyCells, null),
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(monthStart.year, monthStart.month, day),
    ...List<DateTime?>.filled(trailingEmptyCells, null),
  ];
}

class HistoryActivityGrid extends StatefulWidget {
  final Set<DateTime> activityDays;
  final DateTime referenceDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  HistoryActivityGrid({
    super.key,
    required this.activityDays,
    required this.selectedDate,
    required this.onDateSelected,
    DateTime? referenceDate,
  }) : referenceDate = referenceDate ?? DateTime.now();

  @override
  State<HistoryActivityGrid> createState() => _HistoryActivityGridState();
}

class _HistoryActivityGridState extends State<HistoryActivityGrid> {
  int _currentMonthIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentMonthIndex = _selectedMonthIndexForDate(widget.selectedDate);
  }

  int _selectedMonthIndexForDate(DateTime selectedDate) {
    final today = widget.referenceDate.dateOnly;
    final firstActivityDay = widget.activityDays.isEmpty
        ? today
        : widget.activityDays.reduce((a, b) => a.isBefore(b) ? a : b);
    final months = buildMonths(firstDate: firstActivityDay, lastDate: today);
    final selectedMonth = DateTime(selectedDate.year, selectedDate.month);
    final index = months.indexWhere(
      (month) =>
          month.year == selectedMonth.year && month.month == selectedMonth.month,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = widget.referenceDate.dateOnly;
    final firstActivityDay = widget.activityDays.isEmpty
        ? today
        : widget.activityDays.reduce((a, b) => a.isBefore(b) ? a : b);
    final months = buildMonths(firstDate: firstActivityDay, lastDate: today);
    final monthCount = months.length;
    final selectedMonthIndex = _currentMonthIndex
        .clamp(0, monthCount - 1)
        .toInt();
    final selectedMonth = months[selectedMonthIndex];
    final monthLabel = DateFormat.yMMMM().format(selectedMonth);
    final selectedDate = widget.selectedDate.dateOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: selectedMonthIndex < monthCount - 1
                  ? () => _showOlderMonth(months)
                  : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Older month',
            ),
            Expanded(
              child: Center(
                child: Text(monthLabel, style: theme.textTheme.titleSmall),
              ),
            ),
            IconButton(
              onPressed: selectedMonthIndex > 0
                  ? () => _showNewerMonth(months)
                  : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Newer month',
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _MonthCard(
            key: ValueKey(selectedMonth),
            monthStart: selectedMonth,
            referenceDate: today,
            activityDays: widget.activityDays,
            selectedDate: selectedDate,
            onDateSelected: widget.onDateSelected,
          ),
        ),
      ],
    );
  }

  void _showOlderMonth(List<DateTime> months) {
    if (_currentMonthIndex >= months.length - 1) {
      return;
    }

    final nextIndex = _currentMonthIndex + 1;
    setState(() => _currentMonthIndex = nextIndex);
    widget.onDateSelected(months[nextIndex].dateOnly);
  }

  void _showNewerMonth(List<DateTime> months) {
    if (_currentMonthIndex <= 0) {
      return;
    }

    final nextIndex = _currentMonthIndex - 1;
    setState(() => _currentMonthIndex = nextIndex);
    widget.onDateSelected(months[nextIndex].dateOnly);
  }
}

class _MonthCard extends StatelessWidget {
  final DateTime monthStart;
  final DateTime referenceDate;
  final Set<DateTime> activityDays;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _MonthCard({
    super.key,
    required this.monthStart,
    required this.referenceDate,
    required this.activityDays,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final monthCells = buildMonthCells(monthStart);

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _WeekdayHeaderRow(),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: monthCells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final day = monthCells[index];
                if (day == null) {
                  return const SizedBox.shrink();
                }

                final hasActivity = activityDays.contains(day);
                final isFuture = day.isAfter(referenceDate);
                final isSelected = day == selectedDate;
                return _DayCell(
                  day: day,
                  hasActivity: hasActivity,
                  isFuture: isFuture,
                  isSelected: isSelected,
                  onTap: isFuture ? null : () => onDateSelected(day),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) => Row(
    children: const [
      _WeekdayLabel(label: 'S'),
      _WeekdayLabel(label: 'M'),
      _WeekdayLabel(label: 'T'),
      _WeekdayLabel(label: 'W'),
      _WeekdayLabel(label: 'T'),
      _WeekdayLabel(label: 'F'),
      _WeekdayLabel(label: 'S'),
    ],
  );
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool hasActivity;
  final bool isFuture;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.hasActivity,
    required this.isFuture,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isSelected
        ? colorScheme.secondaryContainer
        : hasActivity
        ? colorScheme.primaryContainer
        : isFuture
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
        : colorScheme.surfaceContainerHighest;
    final borderColor = isSelected
        ? colorScheme.primary
        : hasActivity
        ? colorScheme.primary.withValues(alpha: 0.5)
        : colorScheme.outlineVariant.withValues(alpha: isFuture ? 0.5 : 1);
    final textColor = isFuture
        ? colorScheme.outline
        : theme.colorScheme.onSurface;

    return Semantics(
      label: _semanticLabel(day, hasActivity, isFuture, isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (!isFuture)
                  Icon(
                    hasActivity ? Icons.check_rounded : Icons.remove_rounded,
                    size: 16,
                    color: hasActivity
                        ? colorScheme.primary
                        : colorScheme.outline,
                  )
                else
                  const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel(
    DateTime day,
    bool hasActivity,
    bool isFuture,
    bool isSelected,
  ) =>
      '${day.year}-${day.month}-${day.day}, ${isSelected ? 'selected, ' : ''}${isFuture
          ? 'future'
          : hasActivity
          ? 'interacted'
          : 'no interaction'}';
}
