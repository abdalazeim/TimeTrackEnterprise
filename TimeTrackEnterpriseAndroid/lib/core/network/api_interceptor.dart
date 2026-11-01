import 'package:dio/dio.dart';

import '../auth/session_manager.dart';

/// يضيف رأس Bearer ويعالج 401 بتجديد واحد ثم يعيد الطلب مرة واحدة.
class ApiInterceptor extends Interceptor {
  ApiInterceptor({required SessionManager session, required Dio dio})
      : _session = session,
        _dio = dio;

  final SessionManager _session;
  final Dio _dio;

  /// ضعها في `extra` لطلب عام لا يحتاج مصادقة (مثل تسجيل الدخول).
  static const String skipAuthKey = 'app.network.skip_auth';

  /// يُضاف تلقائيًا بعد إعادة المحاولة لمنع الحلقات.
  static const String retriedKey = 'app.network.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final token = _session.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = options.extra[retriedKey] == true;
    final isPublic = options.extra[skipAuthKey] == true;

    if (!isUnauthorized || isPublic || alreadyRetried) {
      return handler.next(err);
    }

    final newAccess = await _session.refreshAccessToken();
    if (newAccess == null || newAccess.isEmpty) {
      return handler.next(err);
    }

    final retryRequest = options.copyWith(
      headers: <String, dynamic>{
        ...options.headers,
        'Authorization': 'Bearer $newAccess',
      },
      extra: <String, dynamic>{...options.extra, retriedKey: true},
    );

    try {
      final response = await _dio.fetch<dynamic>(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
