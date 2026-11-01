import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/database/dao/sync_records_dao.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late SyncRecordsDao dao;

  setUp(() async {
    database = createTestDatabase();
    await database.open();
    dao = SyncRecordsDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('upsertMany يخزن الصفوف ويقرأها', () async {
    final written = await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'R-1',
        'reference': 'REF-1',
        'status': 'draft',
        'updated_at': '2026-01-01T10:00:00Z',
      },
      <String, dynamic>{
        'id': 'R-2',
        'reference': 'REF-2',
        'status': 'loaded',
        'updated_at': '2026-01-01T11:00:00Z',
      },
    ]);

    expect(written, 2);
    expect(await dao.count('record'), 2);
    final record = await dao.find('record', 'R-1');
    expect(record?.payload['reference'], 'REF-1');
    expect(record?.serverUpdatedAt, DateTime.parse('2026-01-01T10:00:00Z'));
  });

  test('يتجاهل الصفوف بلا مفتاح', () async {
    final written = await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'reference': 'no-id'},
      <String, dynamic>{'id': 'R-1', 'reference': 'ok'},
    ]);

    expect(written, 1);
    expect(await dao.count('record'), 1);
  });

  test('تحديث من الخادم يستبدل الصف النظيف', () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-1', 'reference': 'REF-1'},
    ]);
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-1', 'reference': 'REF-2'},
    ]);

    expect((await dao.find('record', 'R-1'))?.payload['reference'], 'REF-2');
  });

  test('لا يطمس صفًا عليه تعديل محلي معلّق', () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-1', 'reference': 'REF-1'},
    ]);
    final db = await database.open();
    await db.update(
      'sync_records',
      <String, Object?>{'dirty': 1},
      where: 'record_id = ?',
      whereArgs: <Object?>['R-1'],
    );

    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-1', 'reference': 'من الخادم'},
    ]);

    final record = await dao.find('record', 'R-1');
    expect(record?.payload['reference'], 'REF-1');
    expect(record?.dirty, isTrue);
  });

  test('applyTombstone يحذف الصف النظيف فقط', () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-1'},
      <String, dynamic>{'id': 'R-2'},
    ]);
    final db = await database.open();
    await db.update(
      'sync_records',
      <String, Object?>{'dirty': 1},
      where: 'record_id = ?',
      whereArgs: <Object?>['R-1'],
    );

    final applied = await dao.applyTombstone(model: 'record', objectPk: 'R-2');
    final skipped = await dao.applyTombstone(model: 'record', objectPk: 'R-1');

    expect(applied, 1);
    expect(skipped, 0);
    expect((await dao.find('record', 'R-2'))?.deleted, isTrue);
    expect((await dao.find('record', 'R-1'))?.deleted, isFalse);
    expect(await dao.count('record'), 1);
  });

  test('receiveTombstone يحتفظ بعلامة الحذف حتى قبل تنزيل الصف', () async {
    await dao.receiveTombstone(
      model: 'record',
      objectPk: 'R-missing',
      deletedAt: DateTime.utc(2026, 1, 1),
    );

    final db = await database.open();
    final tombstones = await db.query('sync_tombstones');
    expect(tombstones, hasLength(1));
    expect(tombstones.single['object_pk'], 'R-missing');
    expect(tombstones.single['applied'], 0);
  });

  test('نتيجة push المعتمدة تستبدل الصف المحلي المعلّق وتثبته نظيفًا',
      () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-ack', 'name': 'local'},
    ]);
    final db = await database.open();
    await db.update(
      'sync_records',
      <String, Object?>{'dirty': 1, 'pending_delete': 1},
      where: 'record_id = ?',
      whereArgs: <Object?>['R-ack'],
    );

    final applied = await dao.applyServerRow(
      'record',
      <String, dynamic>{'id': 'R-ack', 'name': 'canonical'},
    );
    final record = await dao.find('record', 'R-ack');

    expect(applied, isTrue);
    expect(record?.payload['name'], 'canonical');
    expect(record?.dirty, isFalse);
    expect(record?.deleted, isFalse);
  });

  test('تأكيد الحذف من الخادم يصفّي علامة dirty المحلية', () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{'id': 'R-deleted', 'name': 'local'},
    ]);
    final db = await database.open();
    await db.update(
      'sync_records',
      <String, Object?>{'dirty': 1, 'pending_delete': 1},
      where: 'record_id = ?',
      whereArgs: <Object?>['R-deleted'],
    );

    await dao.applyConfirmedTombstone(
      model: 'record',
      objectPk: 'R-deleted',
      deletedAt: DateTime.utc(2026, 1, 2),
    );

    final record = await dao.find('record', 'R-deleted');
    expect(record?.deleted, isTrue);
    expect(record?.dirty, isFalse);
    expect(await dao.count('record'), 0);
  });

  test('page يستثني المحذوف ويرتب بالأحدث', () async {
    await dao.upsertMany('record', <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'R-1',
        'updated_at': '2026-01-01T09:00:00Z',
      },
      <String, dynamic>{
        'id': 'R-2',
        'updated_at': '2026-01-01T12:00:00Z',
      },
      <String, dynamic>{
        'id': 'R-3',
        'updated_at': '2026-01-01T10:00:00Z',
      },
    ]);
    await dao.applyTombstone(model: 'record', objectPk: 'R-3');

    final page = await dao.page('record');

    expect(page.map((record) => record.id), <String>['R-2', 'R-1']);
    expect(await dao.totalCount(), 2);
  });

  test('find يعيد null لصف غير موجود', () async {
    expect(await dao.find('record', 'missing'), isNull);
  });
}
