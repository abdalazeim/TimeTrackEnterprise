import '../../../../core/error/result.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// يحاول استعادة الجلسة المحفوظة عند بدء التطبيق.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AppUser?>> call() =>
      guardAsync<AppUser?>(_repository.restoreSession);
}
