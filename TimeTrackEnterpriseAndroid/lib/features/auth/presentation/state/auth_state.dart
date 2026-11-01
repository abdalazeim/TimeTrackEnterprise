import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.fieldErrors = const <String, String>{},
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unauthenticated({String? errorMessage})
      : this(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  const AuthState.authenticated(AppUser user)
      : this(status: AuthStatus.authenticated, user: user);

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnknown => status == AuthStatus.unknown;

  static const Object _unset = Object();

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    bool? isSubmitting,
    Object? errorMessage = _unset,
    Map<String, String>? fieldErrors,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _unset) ? this.user : user as AppUser?,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }

  /// رسالة مناسبة للعرض من أي فشل.
  static String? messageOf(Failure failure) =>
      failure is ValidationFailure ? null : failure.message;
}
