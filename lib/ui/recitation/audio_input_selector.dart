import 'package:daily_manna/services/recitation_audio_input.dart';
import 'package:daily_manna/ui/recitation/audio_input_sheet.dart';
import 'package:flutter/material.dart';

class AudioInputSelector extends StatelessWidget {
  const AudioInputSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.loadInputs,
    this.enabled = true,
    this.recording = false,
    this.available = true,
  });

  final RecitationInput selected;
  final ValueChanged<String> onChanged;
  final Future<List<RecitationInput>> Function() loadInputs;
  final bool enabled;
  final bool recording;
  final bool available;

  Future<void> _chooseInput(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      builder: (_) =>
          AudioInputSheet(selected: selected, loadInputs: loadInputs),
    );
    if (id != null && context.mounted) onChanged(id);
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: recording
        ? 'Stop recording to change microphone'
        : 'Choose microphone',
    child: TextButton.icon(
      onPressed: enabled && !recording ? () => _chooseInput(context) : null,
      icon: Icon(
        !available
            ? Icons.mic_off_outlined
            : selected.bluetooth
            ? Icons.bluetooth_audio
            : Icons.mic_none,
        size: 18,
      ),
      label: Text(
        available
            ? selected.displayName
            : '${selected.displayName} · Disconnected',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
