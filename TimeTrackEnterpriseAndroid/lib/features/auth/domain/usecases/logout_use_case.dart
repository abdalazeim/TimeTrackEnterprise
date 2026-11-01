import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => guardAsync<void>(_repository.logout);
}
