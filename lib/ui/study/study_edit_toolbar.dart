import 'package:flutter/material.dart';

class StudyEditToolbar extends StatelessWidget {
  const StudyEditToolbar({
    super.key,
    required this.actions,
    required this.onSave,
  });

  final List<Widget> actions;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actions),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSave,
              tooltip: 'Save',
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    ),
  );
}
