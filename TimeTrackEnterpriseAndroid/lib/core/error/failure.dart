/// أخطاء التطبيق المفهومة، مستقلة عن تفاصيل HTTP.
sealed class Failure {
  const Failure(this.message, {this.code, this.retryable = false});

  final String message;
  final String? code;
  final bool retryable;

  @override
  String toString() => '$runtimeType($code): $message';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code, super.retryable = true});
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message, {super.code, super.retryable = true});
}

final class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.code,
    super.retryable = true,
    this.statusCode,
  });

  final int? statusCode;
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

final class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.code});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code,
    this.fields = const {},
  });

  final Map<String, String> fields;
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {super.code, this.retryAfter});

  final Duration? retryAfter;
}

final class ParseFailure extends Failure {
  const ParseFailure(super.message, {super.code});
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code, super.retryable = true});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.code, super.retryable = true});
}
