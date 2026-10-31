import 'package:flutter/material.dart';

class StudyNoteTitleDialog extends StatefulWidget {
  const StudyNoteTitleDialog({super.key, this.initialTitle});

  final String? initialTitle;

  @override
  State<StudyNoteTitleDialog> createState() => _StudyNoteTitleDialogState();
}

class _StudyNoteTitleDialogState extends State<StudyNoteTitleDialog> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialTitle == null ? 'New study note' : 'Rename study note',
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Title'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty ? null : _submit,
        child: Text(widget.initialTitle == null ? 'Create' : 'Rename'),
      ),
    ],
  );
}
