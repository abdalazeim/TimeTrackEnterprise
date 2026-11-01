import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/database/app_database.dart';
import 'package:generic_template/core/database/dao/sync_log_dao.dart';
import 'package:generic_template/core/database/dao/sync_records_dao.dart';
import 'package:generic_template/core/database/dao/sync_state_dao.dart';
import 'package:generic_template/core/network/api_client.dart';
import 'package:generic_template/core/sync/sync_coordinator.dart';
import 'package:generic_template/core/sync/sync_queue.dart';

import '../helpers/test_database.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  Map<String, dynamic> pushResponse = <String, dynamic>{};
  Map<String, dynamic> pullResponse = <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async =>
      pushResponse;

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async =>
      pullResponse;
}

void main() {
  late AppDatabase database;
  late SyncQueue queue;
  late SyncRecordsDao records;
  late SyncStateDao state;
  late SyncLogDao log;
  late _FakeApiClient client;
  late SyncCoordinator coordinator;

  setUp(() async {
    database = createTestDatabase();
    queue = SyncQueue(database);
    records = SyncRecordsDao(database);
    state = SyncStateDao(database);
    log = SyncLogDao(database);
    client = _FakeApiClient();
    coordinator = SyncCoordinator(
      client: client,
      queue: queue,
      state: state,
      records: records,
      log: log,
      models: const <String>['example.item'],
      identity: () => 'https://api.example.com|9',
    );
  });

  tearDown(() async => database.close());

  test('يدفع العملية، يطبق pull والحذف، ثم يحفظ المؤشر', () async {
    final operation = await queue.enqueue(
      kind: 'example.item.create',
      payload: <String, dynamic>{
        'data': <String, dynamic>{'name': 'local'},
      },
    );
    client.pushResponse = <String, dynamic>{
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'operation_id': operation.operationId,
          'status': 'applied',
          'data': <String, dynamic>{'id': 7, 'name': 'local'},
        },
      ],
    };
    client.pullResponse = <String, dynamic>{
      'rows': <String, dynamic>{
        'example.item': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 8,
            'name': 'server',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ],
      },
      'tombstones': <Map<String, dynamic>>[
        <String, dynamic>{
          'model': 'example.item',
          'id': '8',
          'deleted_at': '2026-01-02T00:00:00Z',
        },
      ],
      'cursor': '2026-01-02T00:00:01Z',
    };

    final summary = await coordinator.sync();

    expect(summary.pushed, 1);
    expect(summary.pulled, 1);
    expect((await queue.find(operation.operationId))?.status.name, 'applied');
    expect((await records.find('example.item', '7'))?.payload['name'], 'local');
    expect((await records.find('example.item', '8'))?.deleted, isTrue);
    expect((await state.ensure()).cursor, '2026-01-02T00:00:01Z');
  });
}
