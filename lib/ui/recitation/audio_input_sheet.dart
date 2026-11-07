import 'package:daily_manna/services/recitation_audio_input.dart';
import 'package:flutter/material.dart';

class AudioInputSheet extends StatefulWidget {
  const AudioInputSheet({
    super.key,
    required this.selected,
    required this.loadInputs,
  });

  final RecitationInput selected;
  final Future<List<RecitationInput>> Function() loadInputs;

  @override
  State<AudioInputSheet> createState() => _AudioInputSheetState();
}

class _AudioInputSheetState extends State<AudioInputSheet> {
  late Future<List<RecitationInput>> _inputs;

  @override
  void initState() {
    super.initState();
    _inputs = Future.sync(widget.loadInputs);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Semantics(
            header: true,
            child: Text(
              'Microphone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        Flexible(
          child: FutureBuilder<List<RecitationInput>>(
            future: _inputs,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    heightFactor: 1,
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Finding microphones',
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load microphones.'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _inputs = Future.sync(widget.loadInputs);
                        }),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                );
              }
              final inputs = snapshot.data ?? [];
              final missing = !inputs.any(
                (input) => input.id == widget.selected.id,
              );
              return ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final input in [...inputs, if (missing) widget.selected])
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      leading: Icon(
                        input.bluetooth
                            ? Icons.bluetooth_audio
                            : Icons.mic_none,
                      ),
                      title: Text(input.displayName),
                      subtitle: missing && input.id == widget.selected.id
                          ? const Text('Disconnected')
                          : null,
                      selected: input.id == widget.selected.id,
                      enabled: !(missing && input.id == widget.selected.id),
                      trailing: input.id == widget.selected.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, input.id),
                    ),
                  if (!inputs.any((input) => input.bluetooth))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                      child: Text(
                        'For Bluetooth, connect a headset in Android Settings, then reopen this list.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
