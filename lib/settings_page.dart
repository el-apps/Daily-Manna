import 'dart:async';

import 'package:daily_manna/services/error_logger_service.dart';
import 'package:flutter/gestures.dart';
import 'package:daily_manna/services/settings_service.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui/settings/notification_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final errorLoggerService = context.read<ErrorLoggerService>();

    return AppScaffold(
      title: 'Settings',
      showShareButton: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NotificationCard(),
            const SizedBox(height: 16),
            _ApiKeySection(),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: errorLoggerService,
              builder: (context, _) => _ErrorLogsSection(
                errorLoggerService: errorLoggerService,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLogsSection extends StatelessWidget {
  final ErrorLoggerService errorLoggerService;

  const _ErrorLogsSection({required this.errorLoggerService});

  @override
  Widget build(BuildContext context) {
    final logs = errorLoggerService.getLogs();

    if (logs.isEmpty) {
      return ThemeCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No errors logged',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return ThemeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Error Logs — For Debugging (${logs.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    tooltip: 'Copy logs',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: errorLoggerService.getLogsAsText(),
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Logs copied. You can paste them into an email or message to the developer.',
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear logs',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Logs?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () {
                                errorLoggerService.clearLogs();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                logs.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeySection extends StatefulWidget {
  const _ApiKeySection();

  @override
  State<_ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends State<_ApiKeySection> {
  late SettingsService _settingsService;
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _settingsService = context.read<SettingsService>();
    _checkApiKeyStatus();
  }

  void _checkApiKeyStatus() {
    setState(() {
      final key = _settingsService.getOpenRouterApiKey();
      _hasApiKey = key != null && key.isNotEmpty;
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    final currentContext = context;
    showDialog(
      context: currentContext,
      builder: (ctx) => _ApiKeyDialog(
        controller: controller,
        settingsService: _settingsService,
        onSave: (key) {
          Navigator.pop(ctx);
          _settingsService
              .setOpenRouterApiKey(key)
              .then((_) async {
                if (!mounted) return;
                _checkApiKeyStatus();
                unawaited(
                  Future.microtask(() {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(currentContext).showSnackBar(
                      const SnackBar(content: Text('API key saved')),
                    );
                  }),
                );
              })
              .catchError((_) {
                // Ignore errors, already handled in service
              });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'API Configuration',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OpenRouter API Key',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasApiKey ? '✓ Configured' : '✗ Not configured',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _hasApiKey ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: _showApiKeyDialog,
              child: const Text('Set Key'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            children: [
              const TextSpan(text: 'Get your key from '),
              TextSpan(
                text: 'https://openrouter.ai/keys',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () =>
                      launchUrl(Uri.parse('https://openrouter.ai/keys')),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ApiKeyDialog extends StatelessWidget {
  final TextEditingController controller;
  final SettingsService settingsService;
  final void Function(String key) onSave;

  const _ApiKeyDialog({
    required this.controller,
    required this.settingsService,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Set OpenRouter API Key'),
    content: TextField(
      autofillHints: [AutofillHints.password],
      controller: controller,
      obscureText: true,
      decoration: const InputDecoration(hintText: 'Paste your API key here'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => onSave(controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}
