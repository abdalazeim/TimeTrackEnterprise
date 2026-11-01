import 'package:dio/dio.dart';

import '../error/failure.dart';
import '../error/result.dart';

/// استثناء يحمل [Failure] واحدة عند حدود طبقة الشبكة.
class ApiException implements ApiFailureCarrier {
  const ApiException(this.failure);

  @override
  final Failure failure;

  @override
  String toString() => 'ApiException($failure)';
}

/// تحويل أخطاء Dio والاستجابات إلى [Failure] مفهومة.
class FailureMapper {
  const FailureMapper._();

  static Failure fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutFailure(
          'انتهت مهلة الاتصال بالخادم. قد يكون الخادم في وضع السكون، أعد المحاولة.',
        );
      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت ثم أعد المحاولة.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkFailure('تعذر التحقق من شهادة أمان الخادم.');
      case DioExceptionType.cancel:
        return const NetworkFailure('تم إلغاء الطلب.', retryable: false);
      case DioExceptionType.badResponse:
        return fromResponse(
          statusCode: error.response?.statusCode,
          body: error.response?.data,
          headers: error.response?.headers,
        );
      case DioExceptionType.unknown:
        return NetworkFailure(
          'تعذر إكمال الطلب. تحقق من الشبكة ثم أعد المحاولة.',
          code: error.message,
        );
    }
  }

  static Failure fromResponse({
    int? statusCode,
    Object? body,
    Headers? headers,
  }) {
    final map = body is Map ? body : null;
    final serverMessage = map == null ? null : _messageOf(map);
    final fields = map == null ? const <String, String>{} : _fieldsOf(map);

    switch (statusCode) {
      case 400:
      case 422:
        return ValidationFailure(
          serverMessage ?? 'البيانات المرسلة غير صالحة.',
          fields: fields,
        );
      case 401:
        return const AuthFailure('انتهت الجلسة أو بيانات الدخول غير صحيحة.');
      case 403:
        return PermissionFailure(
          serverMessage ?? 'لا تملك صلاحية لتنفيذ هذا الإجراء.',
        );
      case 404:
        return NotFoundFailure(serverMessage ?? 'العنصر المطلوب غير موجود.');
      case 409:
        return ConflictFailure(
          serverMessage ?? 'حدث تعارض في البيانات، حدّث ثم أعد المحاولة.',
        );
      case 429:
        return RateLimitFailure(
          'تم تجاوز حد الطلبات المسموح. انتظر قليلًا ثم أعد المحاولة.',
          retryAfter: _retryAfter(headers),
        );
    }

    if (statusCode != null && statusCode >= 500) {
      return ServerFailure(
        serverMessage ?? 'حدث خطأ في الخادم. أعد المحاولة لاحقًا.',
        statusCode: statusCode,
      );
    }

    return UnexpectedFailure(
      serverMessage ?? 'حدث خطأ غير متوقع.',
      code: statusCode?.toString(),
    );
  }

  static Failure fromEnvelope(Map<dynamic, dynamic> body) {
    final message = _messageOf(body) ?? 'لم يكتمل الطلب.';
    final fields = _fieldsOf(body);
    return ValidationFailure(message, fields: fields);
  }

  static String? _messageOf(Map<dynamic, dynamic> body) {
    for (final key in const ['error', 'message', 'detail']) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static Map<String, String> _fieldsOf(Map<dynamic, dynamic> body) {
    final raw = body['errors'] ?? body['fields'];
    if (raw is! Map) return const {};

    final fields = <String, String>{};
    raw.forEach((key, value) {
      if (value is String) {
        fields['$key'] = value;
      } else if (value is List && value.isNotEmpty) {
        fields['$key'] = value.join('، ');
      } else if (value != null) {
        fields['$key'] = '$value';
      }
    });
    return fields;
  }

  static Duration? _retryAfter(Headers? headers) {
    final raw = headers?.value('retry-after');
    final seconds = int.tryParse(raw ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
