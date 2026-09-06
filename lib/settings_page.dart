import 'package:daily_manna/services/error_logger_service.dart';
import 'package:daily_manna/services/auth_service.dart';
import 'package:daily_manna/services/sync_service.dart';
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
            const _AccountSyncSection(),
            const SizedBox(height: 16),
            const NotificationCard(),
            const SizedBox(height: 16),
            const _DatabaseExportSection(),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: errorLoggerService,
              builder: (context, _) =>
                  _ErrorLogsSection(errorLoggerService: errorLoggerService),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSyncSection extends StatefulWidget {
  const _AccountSyncSection();
  @override
  State<_AccountSyncSection> createState() => _AccountSyncSectionState();
}

class _AccountSyncSectionState extends State<_AccountSyncSection> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      await context.read<SyncService>().sync();
      if (mounted) {
        _message('Sync complete.');
      }
    } catch (_) {
      if (mounted) {
        _message('Could not sync. Check your connection and account.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign in for sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    final authService = context.read<AuthService>();
    final syncService = context.read<SyncService>();
    setState(() => _busy = true);
    try {
      await authService.signIn(email.text, password.text);
      await syncService.sync();
      if (mounted) {
        _message('Signed in and synced.');
      }
    } catch (error) {
      if (mounted) {
        _message(
          error is AuthException
              ? error.message
              : 'Signed in, but sync could not complete.',
        );
      }
    } finally {
      email.dispose();
      password.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Consumer<AuthService>(
    builder: (context, auth, _) => ThemeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            auth.isSignedIn
                ? 'Signed in as ${auth.email ?? 'your account'}.'
                : 'Sign in to sync across devices.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (!auth.isSignedIn)
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                ),
              if (auth.isSignedIn) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : _sync,
                  icon: const Icon(Icons.sync),
                  label: Text(_busy ? 'Syncing...' : 'Sync now'),
                ),
                TextButton(
                  onPressed: _busy ? null : auth.signOut,
                  child: const Text('Sign out'),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
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
        Text('Export Database', style: Theme.of(context).textTheme.titleMedium),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                        ClipboardData(text: errorLoggerService.getLogsAsText()),
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
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
