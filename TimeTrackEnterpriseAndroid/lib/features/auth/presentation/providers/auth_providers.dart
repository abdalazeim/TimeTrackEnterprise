import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../domain/usecases/logout_use_case.dart';
import '../../domain/usecases/restore_session_use_case.dart';
import '../state/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    session: ref.watch(sessionManagerProvider),
    profiles: ref.watch(profileStoreProvider),
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final restoreSessionUseCaseProvider = Provider<RestoreSessionUseCase>(
  (ref) => RestoreSessionUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  bool _restoreStarted = false;

  @override
  AuthState build() {
    final session = ref.watch(sessionManagerProvider);
    final subscription = session.events.listen(_onSessionEvent);
    ref.onDispose(subscription.cancel);

    if (!_restoreStarted) {
      _restoreStarted = true;
      // بعد انتهاء البناء، حتى لا نعدّل الحالة أثناءه.
      Future<void>.microtask(_restore);
    }

    return const AuthState.unknown();
  }

  void _onSessionEvent(SessionEvent event) {
    final ended = event.type == SessionEventType.expired ||
        event.type == SessionEventType.signedOut;
    if (ended && state.status != AuthStatus.unauthenticated) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> _restore() async {
    final result = await ref.read(restoreSessionUseCaseProvider)();
    result.fold(
      (failure) {
        state = AuthState.unauthenticated(errorMessage: failure.message);
      },
      (user) {
        state = user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user);
      },
    );
  }

  /// إعادة المحاولة من شاشة البداية عند فشل الشبكة.
  Future<void> retryRestore() async {
    state = const AuthState.unknown();
    await _restore();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
      fieldErrors: const <String, String>{},
    );

    final result = await ref.read(loginUseCaseProvider)(
      username: username,
      password: password,
    );

    var succeeded = false;
    result.fold(
      (failure) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: AuthState.messageOf(failure),
          fieldErrors: failure is ValidationFailure
              ? failure.fields
              : const <String, String>{},
        );
      },
      (session) {
        succeeded = true;
        state = AuthState.authenticated(session.user);
      },
    );

    return succeeded;
  }

  Future<void> logout() async {
    state = state.copyWith(isSubmitting: true);
    await ref.read(logoutUseCaseProvider)();
    state = const AuthState.unauthenticated();
  }

  void clearErrors() {
    if (state.errorMessage == null && state.fieldErrors.isEmpty) return;
    state = state.copyWith(
      errorMessage: null,
      fieldErrors: const <String, String>{},
    );
  }
}
