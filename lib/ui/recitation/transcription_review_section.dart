import 'package:flutter/material.dart';

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
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: onSubmit,
              child: const Text('Submit'),
            ),
          ),
        ],
      ),
    ],
  );
}
