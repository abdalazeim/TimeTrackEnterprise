import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/sync/backoff.dart';
import 'package:generic_template/core/sync/pending_operation.dart';
import 'package:generic_template/core/sync/sync_queue.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late DateTime now;
  late SyncQueue queue;

  setUp(() async {
    database = createTestDatabase();
    await database.open();
    now = DateTime.utc(2026, 1, 1, 12);
    queue = SyncQueue(
      database,
      clock: () => now,
      backoff: const Backoff(
        base: Duration(seconds: 10),
        maxDelay: Duration(minutes: 5),
        maxAttempts: 2,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('الإدخال بنفس operationId لا يكرر العملية', () async {
    final operation = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'reference': 'REF-1'},
      entityType: 'record',
      entityId: 'R-1',
    );

    final duplicate = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'reference': 'REF-1-changed'},
      operationId: operation.operationId,
    );

    expect(duplicate.operationId, operation.operationId);
    expect(duplicate.payload['reference'], 'REF-1');
    expect(await queue.count(), 1);
  });

  test('due يعيد الأقدم أولًا', () async {
    final first = await queue.enqueue(
      kind: 'record.update',
      payload: <String, dynamic>{'id': 'R-1'},
    );
    now = now.add(const Duration(minutes: 1));
    final second = await queue.enqueue(
      kind: 'trip.advance',
      payload: <String, dynamic>{'id': 'T-1'},
    );

    final due = await queue.due();

    expect(due.map((operation) => operation.operationId), <String>[
      first.operationId,
      second.operationId,
    ]);
  });

  test('markApplied يخرج العملية من الاستحقاق', () async {
    final operation = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'id': 'R-1'},
    );

    await queue.markSent(operation.operationId);
    expect((await queue.find(operation.operationId))?.status, OperationStatus.sent);

    await queue.markApplied(operation.operationId);

    final stored = await queue.find(operation.operationId);
    expect(stored?.status, OperationStatus.applied);
    expect(await queue.due(), isEmpty);
    expect((await queue.counts())[OperationStatus.applied], 1);
  });

  test('الفشل العابر يطبق Backoff ثم يعلن dead عند السقف', () async {
    final operation = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'id': 'R-1'},
    );

    final firstFailure = await queue.markFailed(
      operation.operationId,
      message: 'timeout',
      statusCode: 503,
    );

    expect(firstFailure?.status, OperationStatus.failed);
    expect(firstFailure?.attempts, 1);
    expect(firstFailure?.lastStatusCode, 503);
    expect(
      firstFailure?.nextAttemptAt,
      now.add(const Duration(seconds: 10)),
    );
    expect(await queue.due(), isEmpty, reason: 'لم يحن موعد المحاولة');

    now = now.add(const Duration(seconds: 11));
    expect(await queue.due(), hasLength(1));

    final secondFailure = await queue.markFailed(
      operation.operationId,
      message: 'timeout again',
    );

    expect(secondFailure?.status, OperationStatus.dead);
    expect(secondFailure?.attempts, 2);
    expect(secondFailure?.nextAttemptAt, isNull);
    expect(await queue.due(), isEmpty);
    expect((await queue.counts())[OperationStatus.dead], 1);
  });

  test('retryDead يعيد العملية إلى الطابور', () async {
    final operation = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'id': 'R-1'},
    );
    await queue.markFailed(operation.operationId, message: 'x');
    await queue.markFailed(operation.operationId, message: 'x');
    expect((await queue.find(operation.operationId))?.status, OperationStatus.dead);

    await queue.retryDead(operation.operationId);

    final revived = await queue.find(operation.operationId);
    expect(revived?.status, OperationStatus.failed);
    expect(revived?.attempts, 0);
    expect(await queue.due(), hasLength(1));
  });

  test('الرفض الدائم لا يعاد تلقائيًا', () async {
    final operation = await queue.enqueue(
      kind: 'record.update',
      payload: <String, dynamic>{'id': 'R-1'},
    );

    await queue.markRejected(
      operation.operationId,
      message: 'انتقال غير صالح',
      statusCode: 422,
    );

    final stored = await queue.find(operation.operationId);
    expect(stored?.status, OperationStatus.rejected);
    expect(stored?.lastStatusCode, 422);
    expect(await queue.due(), isEmpty);
    expect((await queue.counts())[OperationStatus.rejected], 1);
  });

  test('counts يبدأ بكل الحالات صفرًا', () async {
    final counts = await queue.counts();
    expect(counts.keys, containsAll(OperationStatus.values));
    expect(counts.values.every((value) => value == 0), isTrue);
  });

  test('toPushJson يحمل triple (operation_id, kind, payload) فقط', () async {
    final operation = await queue.enqueue(
      kind: 'record.create',
      payload: <String, dynamic>{'reference': 'REF-1'},
    );

    expect(
      operation.toPushJson().keys,
      containsAll(<String>[
        'operation_id',
        'kind',
        'payload',
      ]),
    );
  });
}
