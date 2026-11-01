import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/database/dao/sync_records_dao.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late String scope;
  late AppDatabase database;
  late SyncRecordsDao records;

  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('generic-template-db-');
    scope = 'https://server-a.example|user-9';
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'generic_template.db'),
      scopeKey: () => scope,
    );
    records = SyncRecordsDao(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('الحساب والخادم يحصلان على قاعدة مستقلة عند تبديل الهوية', () async {
    await records.upsertMany('example.item', <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'user nine'},
    ]);

    scope = 'https://server-a.example|user-10';
    expect(await records.count('example.item'), 0);
    await records.upsertMany('example.item', <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'name': 'user ten'},
    ]);

    scope = 'https://server-b.example|user-9';
    expect(await records.count('example.item'), 0);

    scope = 'https://server-a.example|user-9';
    final restored = await records.find('example.item', '1');
    expect(restored?.payload['name'], 'user nine');
  });
}
