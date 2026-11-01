/// مخطط قاعدة البيانات المحلية (إصدار 1).
///
/// التصميم هجين:
/// - `sync_records` جدول عام يخدم النماذج العشرين دون 20 DAO.
/// - `pending_operations` طابور عمليات بحالات واضحة وBackoff.
/// - `sync_tombstones` لسجلات الحذف القادمة من الخادم.
/// - `sync_log` للتشخيص.
class DatabaseSchema {
  const DatabaseSchema._();

  static const int version = 1;

  static const List<String> createStatements = <String>[
    '''
    CREATE TABLE sync_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      cursor TEXT,
      last_sync_at TEXT,
      last_status TEXT,
      device_id TEXT NOT NULL,
      schema_version INTEGER NOT NULL DEFAULT 1
    )
    ''',
    '''
    CREATE TABLE sync_records (
      model TEXT NOT NULL,
      record_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      server_updated_at TEXT,
      local_updated_at TEXT,
      base_updated_at TEXT,
      deleted INTEGER NOT NULL DEFAULT 0,
      pending_delete INTEGER NOT NULL DEFAULT 0,
      dirty INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (model, record_id)
    )
    ''',
    '''
    CREATE INDEX idx_records_model_updated
      ON sync_records (model, server_updated_at)
    ''',
    '''
    CREATE INDEX idx_records_dirty ON sync_records (dirty)
    ''',
    '''
    CREATE TABLE pending_operations (
      operation_id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      entity_type TEXT,
      entity_id TEXT,
      payload TEXT NOT NULL,
      status TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at TEXT,
      last_error TEXT,
      last_status_code INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE INDEX idx_ops_due
      ON pending_operations (status, next_attempt_at)
    ''',
    '''
    CREATE TABLE sync_tombstones (
      model TEXT NOT NULL,
      object_pk TEXT NOT NULL,
      received_at TEXT NOT NULL,
      applied INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (model, object_pk)
    )
    ''',
    '''
    CREATE TABLE sync_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at TEXT NOT NULL,
      finished_at TEXT,
      result TEXT,
      pulled INTEGER NOT NULL DEFAULT 0,
      pushed INTEGER NOT NULL DEFAULT 0,
      failed INTEGER NOT NULL DEFAULT 0,
      error TEXT
    )
    ''',
  ];

  /// ترحيلات مستقبلية: `migrations[2]` يحتوي جمل الإصدار الثاني، وهكذا.
  static const Map<int, List<String>> migrations = <int, List<String>>{};
}
