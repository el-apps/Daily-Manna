import 'package:share_plus/share_plus.dart';

class DatabaseExportFile {
  final XFile file;
  final String fileName;

  const DatabaseExportFile({required this.file, required this.fileName});
}

String buildDatabaseExportFileName(DateTime timestamp, {required String extension}) {
  final local = timestamp.toLocal();
  final date = [
    local.year.toString().padLeft(4, '0'),
    local.month.toString().padLeft(2, '0'),
    local.day.toString().padLeft(2, '0'),
  ].join('');
  final time = [
    local.hour.toString().padLeft(2, '0'),
    local.minute.toString().padLeft(2, '0'),
    local.second.toString().padLeft(2, '0'),
  ].join('');
  return 'daily_manna-export-$date-$time.$extension';
}
