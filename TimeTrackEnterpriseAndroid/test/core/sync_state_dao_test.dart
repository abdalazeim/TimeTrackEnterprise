import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/database/dao/sync_state_dao.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = createTestDatabase();
    await database.open();
  });

  tearDown(() async {
    await database.close();
  });

  test('ensure ينشئ صفًا واحدًا بمعرّف جهاز ثابت', () async {
    final dao = SyncStateDao(database);

    final first = await dao.ensure();
    final second = await dao.ensure();

    expect(first.deviceId, isNotEmpty);
    expect(second.deviceId, first.deviceId);
    expect(first.cursor, isNull);
    expect(first.lastSyncAt, isNull);

    final db = await database.open();
    expect(await db.query('sync_state'), hasLength(1));
  });

  test('setCursor يثبت المؤشر ووقت المزامنة', () async {
    final fixedNow = DateTime.utc(2026, 1, 2, 8, 30);
    final dao = SyncStateDao(database, clock: () => fixedNow);
    await dao.ensure();

    await dao.setCursor(cursor: '2026-01-02T08:00:00Z');
    final state = await dao.ensure();

    expect(state.cursor, '2026-01-02T08:00:00Z');
    expect(state.lastSyncAt, fixedNow);
    expect(state.lastStatus, 'ok');
    expect(state.hasSyncedBefore, isTrue);
  });

  test('markStatus لا يغيّر المؤشر', () async {
    final dao = SyncStateDao(database, clock: () => DateTime.utc(2026, 1, 3));
    await dao.ensure();
    await dao.setCursor(cursor: 'C-1');

    await dao.markStatus('error');
    final state = await dao.ensure();

    expect(state.lastStatus, 'error');
    expect(state.cursor, 'C-1');
  });
}
