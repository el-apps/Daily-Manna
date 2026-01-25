import 'package:flutter/material.dart';
import 'package:daily_manna/ui/action_button_row.dart';

class TranscriptionReviewSection extends StatelessWidget {
  const TranscriptionReviewSection({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Review Transcription',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: controller,
        maxLines: 8,
        decoration: const InputDecoration(
          hintText: 'Edit transcription if needed...',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 48),
      ActionButtonRow(
        secondaryLabel: 'Back',
        primaryLabel: 'Submit',
        onSecondary: onCancel,
        onPrimary: onSubmit,
      ),
    ],
  );
}
