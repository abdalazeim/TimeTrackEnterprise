import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/error/failure.dart';
import 'package:generic_template/core/network/failure_mapper.dart';

void main() {
  group('FailureMapper.fromResponse', () {
    test('400 → ValidationFailure مع الحقول', () {
      final failure = FailureMapper.fromResponse(
        statusCode: 400,
        body: <String, dynamic>{
          'message': 'خطأ تحقق',
          'errors': <String, dynamic>{
            'name': <String>['مطلوب'],
          },
        },
      );
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fields['name'], 'مطلوب');
    });

    test('401 → AuthFailure', () {
      expect(
        FailureMapper.fromResponse(statusCode: 401),
        isA<AuthFailure>(),
      );
    });

    test('403 → PermissionFailure', () {
      expect(
        FailureMapper.fromResponse(statusCode: 403),
        isA<PermissionFailure>(),
      );
    });

    test('404 → NotFoundFailure', () {
      expect(
        FailureMapper.fromResponse(statusCode: 404),
        isA<NotFoundFailure>(),
      );
    });

    test('409 → ConflictFailure', () {
      expect(
        FailureMapper.fromResponse(statusCode: 409),
        isA<ConflictFailure>(),
      );
    });

    test('429 → RateLimitFailure مع Retry-After', () {
      final failure = FailureMapper.fromResponse(
        statusCode: 429,
        headers: Headers.fromMap(<String, List<String>>{
          'retry-after': <String>['12'],
        }),
      );
      expect(failure, isA<RateLimitFailure>());
      expect((failure as RateLimitFailure).retryAfter, const Duration(seconds: 12));
    });

    test('500 → ServerFailure قابل لإعادة المحاولة', () {
      final failure = FailureMapper.fromResponse(statusCode: 503);
      expect(failure, isA<ServerFailure>());
      expect(failure.retryable, isTrue);
      expect((failure as ServerFailure).statusCode, 503);
    });
  });

  group('FailureMapper.fromDio', () {
    DioException exceptionOf(DioExceptionType type) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: type,
        );

    test('connectionTimeout → TimeoutFailure', () {
      expect(
        FailureMapper.fromDio(exceptionOf(DioExceptionType.connectionTimeout)),
        isA<TimeoutFailure>(),
      );
    });

    test('connectionError → NetworkFailure', () {
      expect(
        FailureMapper.fromDio(exceptionOf(DioExceptionType.connectionError)),
        isA<NetworkFailure>(),
      );
    });

    test('cancel → غير قابل لإعادة المحاولة', () {
      final failure =
          FailureMapper.fromDio(exceptionOf(DioExceptionType.cancel));
      expect(failure, isA<NetworkFailure>());
      expect(failure.retryable, isFalse);
    });
  });
}
