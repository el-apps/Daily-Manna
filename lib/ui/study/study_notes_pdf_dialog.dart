import 'package:daily_manna/services/study_notes_pdf.dart';
import 'package:flutter/material.dart';

class StudyNotesPdfDialog extends StatefulWidget {
  const StudyNotesPdfDialog({super.key});

  @override
  State<StudyNotesPdfDialog> createState() => _StudyNotesPdfDialogState();
}

class _StudyNotesPdfDialogState extends State<StudyNotesPdfDialog> {
  StudyNotesPdfFormat _format = StudyNotesPdfFormat.sequential;
  bool _automaticDuplex = false;

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
              'Half-letter pages in reading order, one page at a time.',
            StudyNotesPdfFormat.opening =>
              'Two consecutive half-letter pages side by side on landscape Letter.',
            StudyNotesPdfFormat.cutAndStack =>
              'Landscape Letter sheets arranged for cutting vertically. '
                  'Stack the right halves on top of the left halves.',
          }),
          if (_format == StudyNotesPdfFormat.cutAndStack) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic duplex'),
              subtitle: Text(
                _automaticDuplex
                    ? 'One PDF. Print double-sided with short-edge flip.'
                    : 'Separate fronts and backs PDFs. Flip the stack on the short edge between passes.',
              ),
              value: _automaticDuplex,
              onChanged: (value) => setState(() => _automaticDuplex = value),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Exports your current draft without saving it.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          format: _format,
          automaticDuplex: _automaticDuplex,
        )),
        child: const Text('Generate'),
      ),
    ],
  );
}
