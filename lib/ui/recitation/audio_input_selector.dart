import 'package:daily_manna/services/recitation_audio_input.dart';
import 'package:flutter/material.dart';

class AudioInputSelector extends StatelessWidget {
  const AudioInputSelector({
    super.key,
    required this.inputs,
    required this.selected,
    required this.onChanged,
    required this.onRefresh,
    this.enabled = true,
    this.loading = false,
    this.recording = false,
  });

  final List<RecitationInput> inputs;
  final RecitationInput selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;
  final bool enabled;
  final bool loading;
  final bool recording;

  @override
  Widget build(BuildContext context) {
    final available = inputs.any((input) => input.id == selected.id);
    final options = [...inputs, if (!available) selected];
    final hasBluetooth = inputs.any((input) => input.bluetooth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Audio input',
                  prefixIcon: Icon(
                    selected.bluetooth ? Icons.bluetooth_audio : Icons.mic,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected.id,
                    isExpanded: true,
                    itemHeight: 64,
                    onChanged: enabled && !loading && !recording
                        ? (id) {
                            if (id != null) onChanged(id);
                          }
                        : null,
                    items: options.map((input) {
                      final missing = !available && input.id == selected.id;
                      return DropdownMenuItem(
                        value: input.id,
                        enabled: !missing,
                        child: Text(
                          missing
                              ? '${input.label} (unavailable)'
                              : input.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh microphones',
              onPressed: enabled && !loading && !recording ? onRefresh : null,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          recording
              ? 'Stop recording before changing microphones.'
              : !available
              ? 'Microphone disconnected. Reconnect and refresh, or choose another input.'
              : !hasBluetooth
              ? 'To use Bluetooth, connect a headset in Android Settings, then refresh.'
              : 'Choose a microphone before recording.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
