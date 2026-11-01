import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// التحقق من المدخلات ثم تسجيل الدخول.
class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final errors = <String, String>{};

    if (normalizedUsername.isEmpty) {
      errors['username'] = 'اسم المستخدم مطلوب.';
    }
    if (password.isEmpty) {
      errors['password'] = 'كلمة المرور مطلوبة.';
    }

    if (errors.isNotEmpty) {
      return Err<AuthSession>(
        ValidationFailure(
          'تحقق من الحقول المطلوبة.',
          fields: errors,
        ),
      );
    }

    return guardAsync<AuthSession>(
      () => _repository.login(
        username: normalizedUsername,
        password: password,
      ),
    );
  }
}
