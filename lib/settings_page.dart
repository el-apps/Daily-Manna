import 'package:daily_manna/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _whisperController;
  late TextEditingController _openRouterController;
  late SettingsService _settingsService;

  @override
  void initState() {
    super.initState();
    _settingsService = context.read<SettingsService>();
    _whisperController = TextEditingController(
      text: _settingsService.getWhisperApiKey() ?? '',
    );
    _openRouterController = TextEditingController(
      text: _settingsService.getOpenRouterApiKey() ?? '',
    );
  }

  @override
  void dispose() {
    _whisperController.dispose();
    _openRouterController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_whisperController.text.isEmpty || _openRouterController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all API keys')),
      );
      return;
    }

    await _settingsService.setWhisperApiKey(_whisperController.text);
    await _settingsService.setOpenRouterApiKey(_openRouterController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Text(
            'API Keys',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _whisperController,
            decoration: const InputDecoration(
              labelText: 'Whisper API Key',
              hintText: 'Enter your OpenAI Whisper API key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _openRouterController,
            decoration: const InputDecoration(
              labelText: 'OpenRouter API Key',
              hintText: 'Enter your OpenRouter API key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saveSettings,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}
