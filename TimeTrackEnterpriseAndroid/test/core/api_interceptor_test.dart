import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/auth/session_manager.dart';
import 'package:generic_template/core/network/api_client.dart';
import 'package:generic_template/core/network/api_interceptor.dart';
import 'package:generic_template/core/network/failure_mapper.dart';

import '../helpers/fakes.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responder);

  final Future<ResponseBody> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  const initial = AuthTokens(access: 'old-access', refresh: 'old-refresh');

  (Dio, _RecordingAdapter) buildDio(
    Future<ResponseBody> Function(RequestOptions options) responder,
  ) {
    final adapter = _RecordingAdapter(responder);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.httpClientAdapter = adapter;
    return (dio, adapter);
  }

  test('يضيف رأس Bearer للتطلب المحمي', () async {
    final (dio, adapter) = buildDio(
      (_) async => _json(200, <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'ok': true},
      }),
    );
    final session = SessionManager(
      store: InMemoryTokenStore(initial),
      refreshTokens: (_) async => initial,
    );
    await session.restore();
    dio.interceptors.add(ApiInterceptor(session: session, dio: dio));

    await ApiClient(dio).getMap('/api/v1/modules/example/items/');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer old-access');
  });

  test('لا يضيف الرأس للطلب العام skipAuth', () async {
    final (dio, adapter) = buildDio(
      (_) async => _json(200, <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'ok': true},
      }),
    );
    final session = SessionManager(
      store: InMemoryTokenStore(initial),
      refreshTokens: (_) async => initial,
    );
    await session.restore();
    dio.interceptors.add(ApiInterceptor(session: session, dio: dio));

    await ApiClient(dio).postMap(
      '/api/v1/auth/token/',
      body: <String, dynamic>{'username': 'x', 'password': 'y'},
      authenticated: false,
    );

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('عند 401 يجدّد مرة واحدة ويعيد الطلب بالرمز الجديد', () async {
    final (dio, adapter) = buildDio((options) async {
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer new-access') {
        return _json(200, <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'ok': true},
        });
      }
      return _json(401, <String, dynamic>{
        'success': false,
        'message': 'unauthorized',
      });
    });

    var refreshCalls = 0;
    final store = InMemoryTokenStore(initial);
    final session = SessionManager(
      store: store,
      refreshTokens: (refresh) async {
        refreshCalls++;
        expect(refresh, 'old-refresh');
        return const AuthTokens(access: 'new-access', refresh: 'new-refresh');
      },
    );
    await session.restore();
    dio.interceptors.add(ApiInterceptor(session: session, dio: dio));

    final result = await ApiClient(dio).getMap('/api/v1/x');

    expect(result['ok'], isTrue);
    expect(refreshCalls, 1);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.headers['Authorization'], 'Bearer old-access');
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new-access');
    expect(store.current?.refresh, 'new-refresh');
  });

  test('لا يدخل حلقة لا نهائية إذا بقي 401 بعد التجديد', () async {
    final (dio, adapter) = buildDio(
      (_) async => _json(401, <String, dynamic>{
        'success': false,
        'message': 'unauthorized',
      }),
    );
    final session = SessionManager(
      store: InMemoryTokenStore(initial),
      refreshTokens: (_) async =>
          const AuthTokens(access: 'new-access', refresh: 'new-refresh'),
    );
    await session.restore();
    dio.interceptors.add(ApiInterceptor(session: session, dio: dio));

    await expectLater(
      ApiClient(dio).getMap('/api/v1/x'),
      throwsA(isA<ApiException>()),
    );

    expect(adapter.requests, hasLength(2), reason: 'محاولة أصلية + إعادة واحدة');
  });

  test('فشل التجديد يعيد الخطأ الأصلي دون تكرار', () async {
    final (dio, adapter) = buildDio(
      (_) async => _json(401, <String, dynamic>{
        'success': false,
        'message': 'unauthorized',
      }),
    );
    final session = SessionManager(
      store: InMemoryTokenStore(initial),
      refreshTokens: (_) async => throw StateError('refresh failed'),
    );
    await session.restore();
    dio.interceptors.add(ApiInterceptor(session: session, dio: dio));

    await expectLater(
      ApiClient(dio).getMap('/api/v1/x'),
      throwsA(isA<ApiException>()),
    );

    expect(adapter.requests, hasLength(1));
  });
}
