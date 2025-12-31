import 'package:daily_manna/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecitationMode extends StatefulWidget {
  const RecitationMode({super.key});

  @override
  State<RecitationMode> createState() => _RecitationModeState();
}

class _RecitationModeState extends State<RecitationMode> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeys();
    });
  }

  void _checkApiKeys() {
    final settingsService = context.read<SettingsService>();
    if (!settingsService.hasRequiredKeys()) {
      _showMissingKeysError();
    }
  }

  void _showMissingKeysError() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('API Keys Required'),
        content: const Text(
          'Please configure your Whisper and OpenRouter API keys in Settings before using Recitation Mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recitation Mode')),
      body: Center(
        child: Text(
          'Recitation Mode Coming Soon',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
