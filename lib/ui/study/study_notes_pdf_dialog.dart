import 'package:daily_manna/services/study_notes_pdf.dart';
import 'package:flutter/material.dart';

class StudyNotesPdfDialog extends StatefulWidget {
  const StudyNotesPdfDialog({super.key});

  @override
  State<StudyNotesPdfDialog> createState() => _StudyNotesPdfDialogState();
}

class _StudyNotesPdfDialogState extends State<StudyNotesPdfDialog> {
  StudyNotesPdfFormat _format = StudyNotesPdfFormat.sequential;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Generate PDF'),
    scrollable: true,
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<StudyNotesPdfFormat>(
            initialValue: _format,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Format'),
            items: [
              for (final format in StudyNotesPdfFormat.values)
                DropdownMenuItem(value: format, child: Text(format.label)),
            ],
            onChanged: (format) => setState(() => _format = format!),
          ),
          const SizedBox(height: 16),
          Text(switch (_format) {
            StudyNotesPdfFormat.sequential =>
              'Half-letter pages (5.5 × 8.5 in), one at a time. '
                  'For reading on screen.',
            StudyNotesPdfFormat.opening =>
              'Two half-letter pages side by side on each landscape Letter page. '
                  'For reading a spread on screen.',
            StudyNotesPdfFormat.cutAndStack =>
              'For printers without double-sided printing. '
                  'Print the fronts PDF in landscape at 100%, flip the stack '
                  'on the short edge, then print the backs PDF. '
                  'Cut each sheet down the middle and stack the right halves '
                  'on top of the left halves.',
            StudyNotesPdfFormat.cutAndStackDuplex =>
              'For double-sided printers. Print the PDF in landscape at 100% '
                  'with short-edge flip. Cut each sheet down the middle and '
                  'stack the right halves on top of the left halves.',
          }),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _format),
        child: const Text('Generate'),
      ),
    ],
  );
}
