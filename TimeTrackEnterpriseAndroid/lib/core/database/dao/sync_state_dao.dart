import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';

/// حالة المزامنة العامة للجهاز.
class SyncState {
  const SyncState({
    required this.deviceId,
    this.cursor,
    this.lastSyncAt,
    this.lastStatus,
  });

  final String deviceId;
  final String? cursor;
  final DateTime? lastSyncAt;
  final String? lastStatus;

  bool get hasSyncedBefore => lastSyncAt != null;
}

class SyncStateDao {
  SyncStateDao(
    this._database, {
    Uuid uuid = const Uuid(),
    DateTime Function() clock = _defaultClock,
  })  : _uuid = uuid,
        _clock = clock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// يضمن وجود صف الحالة، وينشئ `device_id` مرة واحدة فقط.
  Future<SyncState> ensure() async {
    final db = await _database.open();
    final rows = await db.query('sync_state', where: 'id = 1', limit: 1);
    if (rows.isNotEmpty) return _fromRow(rows.first);

    final state = <String, Object?>{
      'id': 1,
      'cursor': null,
      'last_sync_at': null,
      'last_status': null,
      'device_id': _uuid.v4(),
      'schema_version': 1,
    };
    await db.insert(
      'sync_state',
      state,
      conflictAlgorithm: _replace,
    );
    return SyncState(deviceId: state['device_id']! as String);
  }

  /// يثبت المؤشر بعد نجاح تطبيق كل الصفحات محليًا.
  Future<void> setCursor({
    required String cursor,
    String status = 'ok',
    DateTime? syncAt,
  }) async {
    final db = await _database.open();
    final now = (syncAt ?? _clock()).toUtc().toIso8601String();
    await db.update(
      'sync_state',
      <String, Object?>{
        'cursor': cursor,
        'last_sync_at': now,
        'last_status': status,
      },
      where: 'id = 1',
    );
  }

  Future<void> markStatus(String status) async {
    final db = await _database.open();
    await db.update(
      'sync_state',
      <String, Object?>{'last_status': status},
      where: 'id = 1',
    );
  }

  SyncState _fromRow(Map<String, Object?> row) {
    final lastSyncRaw = row['last_sync_at'] as String?;
    return SyncState(
      deviceId: (row['device_id'] as String?) ?? '',
      cursor: row['cursor'] as String?,
      lastSyncAt: lastSyncRaw == null ? null : DateTime.tryParse(lastSyncRaw),
      lastStatus: row['last_status'] as String?,
    );
  }

  static const ConflictAlgorithm _replace = ConflictAlgorithm.replace;
}
