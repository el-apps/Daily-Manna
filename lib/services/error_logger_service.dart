import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ErrorLoggerService {
  static const String _logsKey = 'error_logs';
  static const int _maxLogs = 20;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void logError(String message, {String? context}) {
    final timestamp = DateTime.now().toIso8601String();
    final contextPart = context != null ? ' [$context]' : '';
    final logEntry = '[$timestamp]$contextPart $message';
    debugPrint('[ErrorLogger] $logEntry');

    final logs = _prefs.getStringList(_logsKey) ?? [];
    logs.insert(0, logEntry);

    // Keep only last 20 logs
    if (logs.length > _maxLogs) {
      logs.removeRange(_maxLogs, logs.length);
    }

    _prefs.setStringList(_logsKey, logs);
  }

  List<String> getLogs() => _prefs.getStringList(_logsKey) ?? [];

  String getLogsAsText() => getLogs().join('\n');

  Future<void> clearLogs() async {
    await _prefs.remove(_logsKey);
  }
}
