import 'package:flutter/material.dart';
import 'package:daily_manna/passage_range_selector.dart';
import 'package:daily_manna/models/scripture_range_ref.dart';

class RecitationConfirmationSection extends StatelessWidget {
  const RecitationConfirmationSection({
    super.key,
    required this.passageRef,
    required this.onPassageSelected,
    required this.onConfirm,
    required this.onCancel,
  });

  final ScriptureRangeRef passageRef;
  final Function(ScriptureRangeRef) onPassageSelected;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Confirm Passage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 24),
      PassageRangeSelector(
        ref: passageRef,
        onSelected: onPassageSelected,
      ),
      const SizedBox(height: 48),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: onConfirm,
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    ],
  );
}
