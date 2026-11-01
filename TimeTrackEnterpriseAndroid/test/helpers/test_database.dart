import 'package:generic_template/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// قاعدة بيانات FFI في الذاكرة — تسمح باختبار المخطط والاستعلامات على الحاسب.
AppDatabase createTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
}
