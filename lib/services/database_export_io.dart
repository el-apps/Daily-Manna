import 'dart:io';

import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/database_export_models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseExportService {
  final AppDatabase _db;

  DatabaseExportService(this._db);

  Future<DatabaseExportFile> exportDatabase() async {
    final sourcePath = await _getDatabasePath();
    final exportDirectory = await getTemporaryDirectory();
    final fileName = buildDatabaseExportFileName(
      DateTime.now(),
      extension: 'sqlite',
    );
    final exportPath = p.join(exportDirectory.path, fileName);

    final exportFile = File(exportPath);
    if (await exportFile.exists()) {
      await exportFile.delete();
    }

    final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    final destination = sqlite3.open(exportPath);

    try {
      await source.backup(destination, nPage: -1).drain<void>();
    } finally {
      source.dispose();
      destination.dispose();
    }

    return DatabaseExportFile(
      file: XFile(exportPath, name: fileName),
      fileName: fileName,
    );
  }

  Future<String> _getDatabasePath() async {
    final rows = await _db.customSelect('PRAGMA database_list').get();
    final mainDatabase = rows.where((row) => row.read<String>('name') == 'main');
    final row = mainDatabase.isEmpty ? null : mainDatabase.first;
    final path = row?.read<String>('file');

    if (path == null || path.isEmpty) {
      throw StateError('Could not resolve the local database file path.');
    }

    return path;
  }
}
