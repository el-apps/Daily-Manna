import 'package:daily_manna/services/database/database.dart';
import 'package:daily_manna/services/database_export_models.dart';

class DatabaseExportService {
  DatabaseExportService(AppDatabase db);

  Future<DatabaseExportFile> exportDatabase() {
    throw UnsupportedError('Database export is not supported on this platform.');
  }
}
