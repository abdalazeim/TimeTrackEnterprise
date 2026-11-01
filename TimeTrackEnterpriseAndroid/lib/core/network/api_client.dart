import 'package:dio/dio.dart';

import '../error/failure.dart';
import 'api_interceptor.dart';
import 'envelope.dart';
import 'failure_mapper.dart';

/// واجهة واحدة لكل استدعاءات الشبكة، تُحوّل كل خطأ إلى [Failure].
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _run(() async {
      final response = await dio.get<dynamic>(path, queryParameters: query);
      return Envelope.dataMap(response.data);
    });
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) {
    return _run(() async {
      final response = await dio.get<dynamic>(path, queryParameters: query);
      return Envelope.dataList(response.data);
    });
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _run(() async {
      final response = await dio.post<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: _options(authenticated),
      );
      return Envelope.dataMap(response.data);
    });
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) {
    return _run(() async {
      final response = await dio.patch<dynamic>(
        path,
        data: body,
        queryParameters: query,
      );
      return Envelope.dataMap(response.data);
    });
  }

  Future<void> postVoid(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _run(() async {
      final response = await dio.post<dynamic>(
        path,
        data: body,
        options: _options(authenticated),
      );
      Envelope.ensureSuccess(response.data);
    });
  }

  Future<void> deleteVoid(String path) {
    return _run(() async {
      final response = await dio.delete<dynamic>(path);
      Envelope.ensureSuccess(response.data);
    });
  }

  Options? _options(bool authenticated) {
    if (authenticated) return null;
    return Options(
      extra: const <String, dynamic>{ApiInterceptor.skipAuthKey: true},
    );
  }

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw ApiException(FailureMapper.fromDio(error));
    } on FormatException catch (error) {
      throw ApiException(ParseFailure(error.message));
    } catch (error) {
      throw ApiException(UnexpectedFailure('تعذر إكمال الطلب: $error'));
    }
  }
}
