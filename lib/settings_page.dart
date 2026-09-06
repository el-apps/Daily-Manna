import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/database_export.dart';
import 'package:daily_manna/ui/app_scaffold.dart';
import 'package:daily_manna/ui/theme_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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
            const _DatabaseExportSection(),
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

class _DatabaseExportSection extends StatefulWidget {
  const _DatabaseExportSection();

  @override
  State<_DatabaseExportSection> createState() => _DatabaseExportSectionState();
}

class _DatabaseExportSectionState extends State<_DatabaseExportSection> {
  bool _isExporting = false;

  Future<void> _exportDatabase() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final exportService = DatabaseExportService(context.read<AppDatabase>());
      final exportFile = await exportService.exportDatabase();
      await SharePlus.instance.share(
        ShareParams(
          files: [exportFile.file],
          fileNameOverrides: [exportFile.fileName],
          subject: 'Daily Manna database export',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export the database right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ThemeCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text(
          'Export Database',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Create a copy of the local database for backup or analysis.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _isExporting ? null : _exportDatabase,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_isExporting ? 'Exporting...' : 'Export DB'),
          ),
        ),
      ],
    ),
  );
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
