import 'package:flutter/material.dart';

class EditToolbar extends StatelessWidget {
  const EditToolbar({
    super.key,
    required this.editing,
    required this.actions,
    required this.editButton,
    required this.saveButton,
  });

  final bool editing;
  final List<Widget> actions;
  final Widget editButton;
  final Widget saveButton;

  @override
  Widget build(BuildContext context) =>
      editing ? _buildEditingToolbar(context) : editButton;

  Widget _buildEditingToolbar(BuildContext context) => SafeArea(
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
            saveButton,
          ],
        ),
      ),
    ),
  );
}
