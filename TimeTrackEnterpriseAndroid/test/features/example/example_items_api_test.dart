import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/network/api_client.dart';
import 'package:generic_template/core/network/failure_mapper.dart';
import 'package:generic_template/features/example/data/datasources/example_items_api.dart';

void main() {
  group('ExampleItemsApi contract', () {
    late Dio dio;
    late ExampleItemsApi api;
    final requests = <RequestOptions>[];

    setUp(() {
      requests.clear();
      dio = Dio(BaseOptions(baseUrl: 'https://template.example'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            Object? body;
            if (options.method == 'GET') {
              body = <String, Object>{
                'success': true,
                'data': <String, Object>{
                  'items': <Object>[_itemJson()],
                  'meta': <String, Object>{'page': 1, 'page_size': 20},
                },
              };
            } else if (options.method == 'DELETE') {
              body = <String, Object?>{'success': true, 'data': null};
            } else {
              body = <String, Object>{
                'success': true,
                'data': _itemJson(),
              };
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: body,
              ),
            );
          },
        ),
      );
      api = ExampleItemsApi(ApiClient(dio));
    });

    tearDown(() => dio.close());

    test('reads a paginated list and forwards the search term', () async {
      final items = await api.list(query: 'record');

      expect(items, hasLength(1));
      expect(items.single.name, 'Record A');
      expect(requests.single.path, '/api/v1/modules/example/items/');
      expect(requests.single.queryParameters['q'], 'record');
    });

    test('creates, updates, and deletes with the shared API paths', () async {
      await api.create(
        name: 'Record A',
        code: 'REC-001',
        description: 'Sample',
        quantity: 2,
      );
      await api.update(
        7,
        name: 'Record B',
        code: 'REC-002',
        description: '',
        quantity: 3,
      );
      await api.delete(7);

      expect(requests.map((request) => request.method), <String>[
        'POST',
        'PATCH',
        'DELETE',
      ]);
      expect(requests.map((request) => request.path), <String>[
        '/api/v1/modules/example/items/create/',
        '/api/v1/modules/example/items/7/update/',
        '/api/v1/modules/example/items/7/delete/',
      ]);
      expect(requests.first.data['quantity'], 2);
    });

    test('fails when a void API response carries an error envelope', () async {
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: <String, Object>{
                'success': false,
                'message': 'Denied',
                'errors': <String, Object>{},
              },
            ),
          ),
        ),
      );

      await expectLater(api.delete(7), throwsA(isA<ApiException>()));
    });
  });
}

Map<String, Object> _itemJson() => <String, Object>{
      'id': 7,
      'name': 'Record A',
      'code': 'REC-001',
      'description': 'Sample',
      'quantity': 2,
      'is_active': true,
      'created_at': '2026-10-29T09:00:00Z',
      'updated_at': '2026-10-29T09:00:00Z',
    };
