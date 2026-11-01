import 'failure.dart';

/// يحوّل استثناءً واحدًا إلى [Result] دون تسريب استثناءات للواجهة.
Future<Result<T>> guardAsync<T>(Future<T> Function() body) async {
  try {
    return Ok<T>(await body());
  } on ApiFailureCarrier catch (carrier) {
    return Err<T>(carrier.failure);
  } catch (error) {
    return Err<T>(UnexpectedFailure('$error'));
  }
}

/// عقد صغير يفك اعتماد `result.dart` على طبقة الشبكة.
abstract interface class ApiFailureCarrier implements Exception {
  Failure get failure;
}

/// نتيجة صريحة لا تحمل استثناءات إلى الطبقات العليا.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onError, R Function(T value) onOk);

  bool get isOk => this is Ok<T>;

  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  R fold<R>(R Function(Failure failure) onError, R Function(T value) onOk) =>
      onOk(value);
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  R fold<R>(R Function(Failure failure) onError, R Function(T value) onOk) =>
      onError(failure);
}
