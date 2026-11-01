import '../app_database.dart';

/// سجل تشخيصي لدورات المزامنة.
class SyncLogDao {
  SyncLogDao(this._database);

  final AppDatabase _database;

  Future<int> record({
    required DateTime startedAt,
    required String result,
    DateTime? finishedAt,
    int pulled = 0,
    int pushed = 0,
    int failed = 0,
    String? error,
  }) async {
    final db = await _database.open();
    return db.insert('sync_log', <String, Object?>{
      'started_at': startedAt.toUtc().toIso8601String(),
      'finished_at': (finishedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'result': result,
      'pulled': pulled,
      'pushed': pushed,
      'failed': failed,
      'error': error,
    });
  }

  Future<Map<String, Object?>?> last() async {
    final db = await _database.open();
    final rows = await db.query('sync_log', orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> clear() async {
    final db = await _database.open();
    return db.delete('sync_log');
  }
}
