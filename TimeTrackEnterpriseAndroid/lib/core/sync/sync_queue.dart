import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'backoff.dart';
import 'pending_operation.dart';

/// طابور العمليات المحلي — الحالات، الاستحقاق، وإعادة المحاولة.
///
/// لا يتصل بالشبكة إطلاقًا؛ الإرسال مسؤولية `PushService` لاحقًا.
class SyncQueue {
  SyncQueue(
    this._database, {
    Uuid uuid = const Uuid(),
    Backoff backoff = const Backoff(),
    DateTime Function()? clock,
  })  : _uuid = uuid,
        _backoff = backoff,
        _clock = clock ?? _defaultClock;

  static DateTime _defaultClock() => DateTime.now().toUtc();

  final AppDatabase _database;
  final Uuid _uuid;
  final Backoff _backoff;
  final DateTime Function() _clock;

  Backoff get backoff => _backoff;

  /// يضيف عملية. إعادة الاستخدام بنفس `operationId` آمنة (Idempotent محليًا).
  Future<PendingOperation> enqueue({
    required String kind,
    required Map<String, dynamic> payload,
    String? entityType,
    String? entityId,
    String? operationId,
  }) async {
    final db = await _database.open();
    final id = operationId ?? _uuid.v4();
    final now = _clock().toUtc();
    final nowIso = now.toIso8601String();

    final row = <String, Object?>{
      'operation_id': id,
      'kind': kind,
      'entity_type': entityType,
      'entity_id': entityId,
      'payload': jsonEncode(payload),
      'status': OperationStatus.pending.name,
      'attempts': 0,
      'next_attempt_at': null,
      'last_error': null,
      'last_status_code': null,
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    final inserted = await db.insert(
      'pending_operations',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    if (inserted != 0) return PendingOperation.fromRow(row);

    // موجودة مسبقًا: أعد الحالية بلا تعديل.
    final existing = await _find(id);
    if (existing != null) return existing;
    return PendingOperation.fromRow(row);
  }

  /// العمليات المستحقة للإرسال الآن، الأقدم أولًا.
  Future<List<PendingOperation>> due({int limit = 25}) async {
    final db = await _database.open();
    final nowIso = _clock().toUtc().toIso8601String();
    final rows = await db.query(
      'pending_operations',
      where: 'status IN (?, ?, ?) '
          'AND (next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: <Object?>[
        OperationStatus.pending.name,
        OperationStatus.failed.name,
        OperationStatus.sent.name,
        nowIso,
      ],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(PendingOperation.fromRow).toList(growable: false);
  }

  Future<List<PendingOperation>> all({
    int limit = 100,
    bool includeSettled = true,
  }) async {
    final db = await _database.open();
    final rows = await db.query(
      'pending_operations',
      where: includeSettled
          ? null
          : 'status IN (?, ?, ?)',
      whereArgs: includeSettled
          ? null
          : <Object?>[
              OperationStatus.pending.name,
              OperationStatus.failed.name,
              OperationStatus.sent.name,
            ],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(PendingOperation.fromRow).toList(growable: false);
  }

  Future<PendingOperation?> find(String operationId) => _find(operationId);

  Future<void> markSent(String operationId) async {
    await _update(operationId, <String, Object?>{
      'status': OperationStatus.sent.name,
      'last_error': null,
      'last_status_code': null,
    });
  }

  Future<void> markApplied(String operationId) async {
    await _update(operationId, <String, Object?>{
      'status': OperationStatus.applied.name,
      'last_error': null,
      'last_status_code': null,
      'next_attempt_at': null,
    });
  }

  /// رفض دائم: لا إعادة محاولة تلقائية.
  Future<void> markRejected(
    String operationId, {
    required String message,
    int? statusCode,
  }) async {
    await _update(operationId, <String, Object?>{
      'status': OperationStatus.rejected.name,
      'last_error': message,
      'last_status_code': statusCode,
      'next_attempt_at': null,
    });
  }

  /// فشل عابر: يزيد المحاولات ويحدد موعدًا جديدًا أو يعلن `dead`.
  Future<PendingOperation?> markFailed(
    String operationId, {
    required String message,
    int? statusCode,
  }) async {
    final current = await _find(operationId);
    if (current == null) return null;

    final attempts = current.attempts + 1;
    final canRetry = _backoff.canRetry(attempts);
    final nextAttempt = canRetry
        ? _clock().toUtc().add(_backoff.delayFor(attempts)).toIso8601String()
        : null;

    await _update(operationId, <String, Object?>{
      'status':
          canRetry ? OperationStatus.failed.name : OperationStatus.dead.name,
      'attempts': attempts,
      'next_attempt_at': nextAttempt,
      'last_error': message,
      'last_status_code': statusCode,
    });
    return _find(operationId);
  }

  /// يعيد عملية `dead` إلى الطابور يدويًا.
  Future<void> retryDead(String operationId) async {
    await _update(operationId, <String, Object?>{
      'status': OperationStatus.failed.name,
      'attempts': 0,
      'next_attempt_at': null,
      'last_error': null,
      'last_status_code': null,
    });
  }

  Future<Map<OperationStatus, int>> counts() async {
    final db = await _database.open();
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS n FROM pending_operations GROUP BY status',
    );
    final result = <OperationStatus, int>{
      for (final status in OperationStatus.values) status: 0,
    };
    for (final row in rows) {
      final status = OperationStatus.parse(row['status'] as String? ?? '');
      result[status] = (row['n'] as int?) ?? 0;
    }
    return result;
  }

  Future<int> count() async {
    final db = await _database.open();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM pending_operations',
    );
    return (result.first['n'] as int?) ?? 0;
  }

  Future<void> clear() async {
    final db = await _database.open();
    await db.delete('pending_operations');
  }

  Future<PendingOperation?> _find(String operationId) async {
    final db = await _database.open();
    final rows = await db.query(
      'pending_operations',
      where: 'operation_id = ?',
      whereArgs: <Object?>[operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingOperation.fromRow(rows.first);
  }

  Future<void> _update(String operationId, Map<String, Object?> values) async {
    final db = await _database.open();
    await db.update(
      'pending_operations',
      <String, Object?>{
        ...values,
        'updated_at': _clock().toUtc().toIso8601String(),
      },
      where: 'operation_id = ?',
      whereArgs: <Object?>[operationId],
    );
  }
}
