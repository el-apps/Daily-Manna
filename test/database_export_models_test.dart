import 'package:daily_manna/services/database_export_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDatabaseExportFileName', () {
    test('builds sqlite file names with zero-padded local timestamps', () {
      final fileName = buildDatabaseExportFileName(
        DateTime(2024, 5, 6, 7, 8, 9),
        extension: 'sqlite',
      );

      expect(fileName, 'daily_manna-export-20240506-070809.sqlite');
    });

    test('builds json file names with zero-padded local timestamps', () {
      final fileName = buildDatabaseExportFileName(
        DateTime(2024, 11, 12, 13, 14, 15),
        extension: 'json',
      );

      expect(fileName, 'daily_manna-export-20241112-131415.json');
    });
  });
}
