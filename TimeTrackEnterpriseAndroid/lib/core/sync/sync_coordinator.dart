import '../error/failure.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/failure_mapper.dart';
import '../database/dao/sync_log_dao.dart';
import '../database/dao/sync_records_dao.dart';
import '../database/dao/sync_state_dao.dart';
import 'pending_operation.dart';
import 'sync_queue.dart';

/// Coordinates the reusable outbox and cursor pull protocol.
///
/// Domain modules choose their collection names and operation kinds; this
/// class owns retry, response handling, tombstones, and cursor persistence.
class SyncCoordinator {
  SyncCoordinator({
    required ApiClient client,
    required SyncQueue queue,
    required SyncStateDao state,
    required SyncRecordsDao records,
    required SyncLogDao log,
    required String? Function() identity,
    List<String> models = const <String>[],
  })  : _client = client,
        _queue = queue,
        _state = state,
        _records = records,
        _log = log,
        _identity = identity,
        _models = List<String>.unmodifiable(models);

  final ApiClient _client;
  final SyncQueue _queue;
  final SyncStateDao _state;
  final SyncRecordsDao _records;
  final SyncLogDao _log;
  final String? Function() _identity;
  final List<String> _models;
  Future<SyncSummary>? _running;

  Future<SyncSummary> sync() {
    final running = _running;
    if (running != null) return running;
    final future = _run();
    _running = future;
    return future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
  }

  Future<SyncSummary> _run() async {
    final identity = _identity();
    if (identity == null) return const SyncSummary(skipped: true);
    final startedAt = DateTime.now().toUtc();
    var pushed = 0;
    var pulled = 0;
    var failed = 0;
    Object? syncError;

    try {
      final due = await _queue.due(limit: 25);
      if (!_isCurrent(identity)) return const SyncSummary(skipped: true);
      if (due.isNotEmpty) {
        for (final operation in due) {
          await _queue.markSent(operation.operationId);
        }
        try {
          final response = await _client.postMap(
            ApiEndpoints.sync,
            body: <String, dynamic>{
              'operations': due.map((item) => item.toPushJson()).toList(),
            },
          );
          if (!_isCurrent(identity)) return const SyncSummary(skipped: true);
          final counts = await _applyPushResults(due, response);
          pushed += counts.applied;
          failed += counts.failed;
        } catch (error) {
          if (_isCurrent(identity)) {
            for (final operation in due) {
              await _queue.markFailed(
                operation.operationId,
                message: _message(error),
                statusCode: _statusCode(error),
              );
            }
            failed += due.length;
            syncError = error;
          }
        }
      }

      if (_isCurrent(identity)) {
        try {
          pulled += await _pull(identity);
        } catch (error) {
          if (_isCurrent(identity)) syncError ??= error;
        }
      }
    } catch (error) {
      if (_isCurrent(identity)) syncError ??= error;
    }

    if (!_isCurrent(identity)) return const SyncSummary(skipped: true);
    await _state.markStatus(syncError == null ? 'ok' : 'error');
    await _log.record(
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      result: syncError == null ? 'ok' : 'error',
      pushed: pushed,
      pulled: pulled,
      failed: failed,
      error: syncError == null ? null : _message(syncError),
    );
    if (syncError != null) throw syncError;
    return SyncSummary(pushed: pushed, pulled: pulled, failed: failed);
  }

  Future<_PushCounts> _applyPushResults(
    List<PendingOperation> operations,
    Map<String, dynamic> response,
  ) async {
    final rawResults = response['results'];
    if (rawResults is! List) {
      throw const ApiException(
        ParseFailure('Sync response has no results list.'),
      );
    }
    final byId = <String, Map<String, dynamic>>{};
    for (final raw in rawResults) {
      if (raw is Map) {
        final result = raw.cast<String, dynamic>();
        final id = result['operation_id']?.toString();
        if (id != null) byId[id] = result;
      }
    }

    var applied = 0;
    var failed = 0;
    for (final operation in operations) {
      final result = byId[operation.operationId];
      if (result == null) {
        await _queue.markFailed(
          operation.operationId,
          message: 'The server omitted this operation result.',
        );
        failed++;
        continue;
      }
      final status = result['status']?.toString();
      if (status == 'applied') {
        await _queue.markApplied(operation.operationId);
        await _applyOperationData(operation, result['data']);
        applied++;
      } else if (status == 'rejected' || status == 'conflict') {
        await _queue.markRejected(
          operation.operationId,
          message: (result['error'] ?? result['code'] ?? status).toString(),
        );
        failed++;
      } else {
        await _queue.markFailed(
          operation.operationId,
          message: 'Unknown operation status: $status',
        );
        failed++;
      }
    }
    return _PushCounts(applied: applied, failed: failed);
  }

  Future<void> _applyOperationData(
    PendingOperation operation,
    Object? data,
  ) async {
    if (data is! Map) return;
    final row = data.cast<String, dynamic>();
    final collection = _collectionFor(operation.kind);
    if (row['deleted'] == true) {
      final id = row['id']?.toString();
      if (id != null) {
        await _records.applyConfirmedTombstone(
          model: collection,
          objectPk: id,
          deletedAt: DateTime.tryParse('${row['deleted_at']}') ??
              DateTime.now().toUtc(),
        );
      }
      return;
    }
    if (row['id'] != null) {
      await _records.applyServerRow(collection, row);
    }
  }

  Future<int> _pull(String identity) async {
    final current = await _state.ensure();
    final response = await _client.getMap(
      ApiEndpoints.sync,
      query: <String, dynamic>{
        if (current.cursor != null) 'since': current.cursor,
        if (_models.isNotEmpty) 'models': _models.join(','),
      },
    );
    if (!_isCurrent(identity)) return 0;

    final rawRows = response['rows'];
    if (rawRows is! Map) {
      throw const ApiException(ParseFailure('Sync response has no rows map.'));
    }
    var count = 0;
    for (final entry in rawRows.entries) {
      if (!_isCurrent(identity)) return 0;
      if (entry.value is! List) {
        throw const ApiException(
          ParseFailure('Sync collection is not a list.'),
        );
      }
      final rows = (entry.value as List)
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false);
      count += await _records.upsertMany(entry.key.toString(), rows);
    }

    final rawTombstones = response['tombstones'];
    if (rawTombstones is! List) {
      throw const ApiException(
        ParseFailure('Sync response has no tombstones list.'),
      );
    }
    for (final raw in rawTombstones.whereType<Map>()) {
      if (!_isCurrent(identity)) return 0;
      final tombstone = raw.cast<String, dynamic>();
      final model = tombstone['model']?.toString();
      final id = (tombstone['id'] ?? tombstone['object_pk'])?.toString();
      final deletedAt = DateTime.tryParse('${tombstone['deleted_at']}');
      if (model == null || id == null || deletedAt == null) continue;
      await _records.receiveTombstone(
        model: model,
        objectPk: id,
        deletedAt: deletedAt,
      );
    }

    final cursor = response['cursor']?.toString();
    if (cursor == null || DateTime.tryParse(cursor) == null) {
      throw const ApiException(
        ParseFailure('Sync response has an invalid cursor.'),
      );
    }
    if (_isCurrent(identity)) await _state.setCursor(cursor: cursor);
    return count;
  }

  bool _isCurrent(String identity) => _identity() == identity;

  String _collectionFor(String kind) {
    final lastSeparator = kind.lastIndexOf('.');
    return lastSeparator < 1 ? kind : kind.substring(0, lastSeparator);
  }

  String _message(Object error) =>
      error is ApiException ? error.failure.message : error.toString();

  int? _statusCode(Object error) => error is ApiException
      ? switch (error.failure) {
          ServerFailure(:final statusCode) => statusCode,
          _ => null,
        }
      : null;
}

class _PushCounts {
  const _PushCounts({required this.applied, required this.failed});
  final int applied;
  final int failed;
}

class SyncSummary {
  const SyncSummary({
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.skipped = false,
  });

  final int pushed;
  final int pulled;
  final int failed;
  final bool skipped;
}
