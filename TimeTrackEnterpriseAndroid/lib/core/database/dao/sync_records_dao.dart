import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../app_database.dart';

/// صف مُخزَّن من أي نموذج مزامنة.
class SyncRecord {
  const SyncRecord({
    required this.model,
    required this.id,
    required this.payload,
    this.serverUpdatedAt,
    this.dirty = false,
    this.deleted = false,
  });

  final String model;
  final String id;
  final Map<String, dynamic> payload;
  final DateTime? serverUpdatedAt;
  final bool dirty;
  final bool deleted;

  /// يقرأ الحقل بأسماء متعددة (العقد يخلط camelCase وsnake_case).
  Object? field(List<String> names) {
    for (final name in names) {
      if (payload.containsKey(name)) return payload[name];
    }
    return null;
  }
}

/// قراءة/كتابة الجدول العام للنماذج العشرين.
class SyncRecordsDao {
  SyncRecordsDao(this._database);

  final AppDatabase _database;

  /// إدراج/تحديث دفعة. لا يطمس التعديلات المحلية غير المدفوعة.
  ///
  /// يستخدم `INSERT OR IGNORE` ثم `UPDATE ... AND dirty = 0` بدل صيغة
  /// `ON CONFLICT ... DO UPDATE`، لأن الأخيرة تتطلب SQLite 3.24+
  /// بينما يدعم التطبيق أندرويد 7 (SQLite 3.9).
  Future<int> upsertMany(
    String model,
    List<Map<String, dynamic>> rows, {
    String idField = 'id',
  }) async {
    if (rows.isEmpty) return 0;

    final db = await _database.open();
    final batch = db.batch();
    var written = 0;

    for (final row in rows) {
      final id = row[idField]?.toString();
      if (id == null || id.isEmpty) continue;

      final payload = jsonEncode(row);
      final serverUpdated =
          (row['updated_at'] ?? row['created_at'])?.toString();

      // صف جديد: يُدرج نظيفًا. صف موجود: يبقى كما هو هنا.
      batch.rawInsert(
        '''
        INSERT OR IGNORE INTO sync_records
          (model, record_id, payload, server_updated_at, base_updated_at, deleted)
        VALUES (?, ?, ?, ?, ?, 0)
        ''',
        <Object?>[model, id, payload, serverUpdated, serverUpdated],
      );

      // صف موجود ونظيف فقط: يُحدَّث من الخادم. الصفوف المتسخة محمية.
      batch.rawUpdate(
        '''
        UPDATE sync_records
           SET payload = ?,
               server_updated_at = ?,
               base_updated_at = ?,
               deleted = 0
         WHERE model = ? AND record_id = ? AND dirty = 0
        ''',
        <Object?>[payload, serverUpdated, serverUpdated, model, id],
      );
      written++;
    }

    await batch.commit(noResult: true);
    return written;
  }

  /// Applies an acknowledged server row and settles any local dirty marker.
  /// Pulls use [upsertMany] so they never erase a pending local write; a push
  /// acknowledgement is the point where the server version becomes canonical.
  Future<bool> applyServerRow(
    String model,
    Map<String, dynamic> row, {
    String idField = 'id',
  }) async {
    final id = row[idField]?.toString();
    if (id == null || id.isEmpty) return false;
    final serverUpdated = (row['updated_at'] ?? row['created_at'])?.toString();
    final db = await _database.open();
    await db.insert(
      'sync_records',
      <String, Object?>{
        'model': model,
        'record_id': id,
        'payload': jsonEncode(row),
        'server_updated_at': serverUpdated,
        'local_updated_at': null,
        'base_updated_at': serverUpdated,
        'deleted': 0,
        'pending_delete': 0,
        'dirty': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  /// يستبدل كل صفوف نموذج ببيانات الخادم الحالية.
  ///
  /// لا يمسّ الصفوف المتسخة (تعديلات محلية غير مدفوعة)، لكنه يحذف الصفوف
  /// النظيفة التي اختفت من الخادم حتى لا تبقى قوائم قديمة.
  Future<int> replaceAll(
    String model,
    List<Map<String, dynamic>> rows, {
    String idField = 'id',
  }) async {
    final db = await _database.open();
    final batch = db.batch();

    batch.delete(
      'sync_records',
      where: 'model = ? AND dirty = 0',
      whereArgs: <Object?>[model],
    );

    var written = 0;
    for (final row in rows) {
      final id = row[idField]?.toString();
      if (id == null || id.isEmpty) continue;

      final payload = jsonEncode(row);
      final serverUpdated =
          (row['updated_at'] ?? row['created_at'])?.toString();

      batch.rawInsert(
        '''
        INSERT OR IGNORE INTO sync_records
          (model, record_id, payload, server_updated_at, base_updated_at, deleted)
        VALUES (?, ?, ?, ?, ?, 0)
        ''',
        <Object?>[model, id, payload, serverUpdated, serverUpdated],
      );
      batch.rawUpdate(
        '''
        UPDATE sync_records
           SET payload = ?,
               server_updated_at = ?,
               base_updated_at = ?,
               deleted = 0
         WHERE model = ? AND record_id = ? AND dirty = 0
        ''',
        <Object?>[payload, serverUpdated, serverUpdated, model, id],
      );
      written++;
    }

    await batch.commit(noResult: true);
    return written;
  }

  /// يطبّق حذفًا قادمًا من الخادم. لا يحذف صفًا عليه تعديل محلي معلّق.
  Future<int> applyTombstone({
    required String model,
    required String objectPk,
  }) async {
    final db = await _database.open();
    return db.rawUpdate(
      '''
      UPDATE sync_records
         SET deleted = 1,
             payload = '{}'
       WHERE model = ? AND record_id = ? AND dirty = 0
      ''',
      <Object?>[model, objectPk],
    );
  }

  /// Stores a server deletion marker and applies it without overwriting a
  /// locally dirty record. The marker remains available if the row was never
  /// downloaded on this device.
  Future<void> receiveTombstone({
    required String model,
    required String objectPk,
    required DateTime deletedAt,
  }) async {
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.insert(
        'sync_tombstones',
        <String, Object?>{
          'model': model,
          'object_pk': objectPk,
          'received_at': deletedAt.toUtc().toIso8601String(),
          'applied': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final changed = await txn.rawUpdate(
        '''
        UPDATE sync_records
           SET deleted = 1,
               payload = '{}'
         WHERE model = ? AND record_id = ? AND dirty = 0
        ''',
        <Object?>[model, objectPk],
      );
      if (changed > 0) {
        await txn.update(
          'sync_tombstones',
          <String, Object?>{'applied': 1},
          where: 'model = ? AND object_pk = ?',
          whereArgs: <Object?>[model, objectPk],
        );
      }
    });
  }

  /// Settles a local delete after the server has acknowledged it.
  Future<void> applyConfirmedTombstone({
    required String model,
    required String objectPk,
    required DateTime deletedAt,
  }) async {
    final timestamp = deletedAt.toUtc().toIso8601String();
    final db = await _database.open();
    await db.transaction((txn) async {
      await txn.insert(
        'sync_tombstones',
        <String, Object?>{
          'model': model,
          'object_pk': objectPk,
          'received_at': timestamp,
          'applied': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.rawUpdate(
        '''
        UPDATE sync_records
           SET deleted = 1,
               payload = '{}',
               server_updated_at = ?,
               local_updated_at = NULL,
               base_updated_at = ?,
               pending_delete = 0,
               dirty = 0
         WHERE model = ? AND record_id = ?
        ''',
        <Object?>[timestamp, timestamp, model, objectPk],
      );
    });
  }

  Future<SyncRecord?> find(String model, String id) async {
    final db = await _database.open();
    final rows = await db.query(
      'sync_records',
      where: 'model = ? AND record_id = ?',
      whereArgs: <Object?>[model, id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// صفحة من صفوف نموذج، الأحدث أولًا.
  Future<List<SyncRecord>> page(
    String model, {
    int limit = 50,
    int offset = 0,
    bool includeDeleted = false,
  }) async {
    final db = await _database.open();
    final rows = await db.query(
      'sync_records',
      where: includeDeleted ? 'model = ?' : 'model = ? AND deleted = 0',
      whereArgs: <Object?>[model],
      orderBy: 'server_updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<int> count(String model, {bool includeDeleted = false}) async {
    final db = await _database.open();
    final result = await db.rawQuery(
      includeDeleted
          ? 'SELECT COUNT(*) AS n FROM sync_records WHERE model = ?'
          : 'SELECT COUNT(*) AS n FROM sync_records WHERE model = ? AND deleted = 0',
      <Object?>[model],
    );
    return (result.first['n'] as int?) ?? 0;
  }

  Future<int> totalCount() async {
    final db = await _database.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM sync_records WHERE deleted = 0',
    );
    return (result.first['n'] as int?) ?? 0;
  }

  SyncRecord _fromRow(Map<String, Object?> row) {
    final payloadRaw = row['payload'] as String?;
    Map<String, dynamic> payload = const <String, dynamic>{};
    if (payloadRaw != null && payloadRaw.isNotEmpty) {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is Map) payload = decoded.cast<String, dynamic>();
    }

    final updatedRaw = row['server_updated_at'] as String?;
    return SyncRecord(
      model: row['model']! as String,
      id: row['record_id']! as String,
      payload: payload,
      serverUpdatedAt:
          updatedRaw == null ? null : DateTime.tryParse(updatedRaw),
      dirty: (row['dirty'] as int? ?? 0) == 1,
      deleted: (row['deleted'] as int? ?? 0) == 1,
    );
  }
}
