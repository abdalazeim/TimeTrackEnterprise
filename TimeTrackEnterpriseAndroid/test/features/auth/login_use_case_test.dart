import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/error/failure.dart';
import 'package:generic_template/core/error/result.dart';
import 'package:generic_template/core/network/failure_mapper.dart';
import 'package:generic_template/features/auth/domain/entities/app_user.dart';
import 'package:generic_template/features/auth/domain/entities/auth_session.dart';
import 'package:generic_template/features/auth/domain/repositories/auth_repository.dart';
import 'package:generic_template/features/auth/domain/usecases/login_use_case.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.session, this.error});

  final AuthSession? session;
  final Object? error;
  int loginCalls = 0;
  String? lastUsername;
  String? lastPassword;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    lastUsername = username;
    lastPassword = password;
    if (error != null) throw error!;
    return session!;
  }

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> logout() async {}
}

void main() {
  const user = AppUser(id: 1, username: 'ahmed');
  const session = AuthSession(
    tokens: AuthTokens(access: 'a', refresh: 'r'),
    user: user,
  );

  group('LoginUseCase', () {
    test('يرفض الحقول الفارغة دون استدعاء المستودع', () async {
      final repository = _FakeAuthRepository(session: session);
      final result = await LoginUseCase(repository)(
        username: '   ',
        password: '',
      );

      expect(result, isA<Err<AuthSession>>());
      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fields.keys, containsAll(<String>['username', 'password']));
      expect(repository.loginCalls, 0);
    });

    test('يقص المسافات حول اسم المستخدم', () async {
      final repository = _FakeAuthRepository(session: session);
      final result = await LoginUseCase(repository)(
        username: '  ahmed  ',
        password: 'secret',
      );

      expect(result, isA<Ok<AuthSession>>());
      expect(repository.lastUsername, 'ahmed');
      expect(repository.lastPassword, 'secret');
    });

    test('يمرر الفشل من طبقة الشبكة كما هو', () async {
      final repository = _FakeAuthRepository(
        error: const ApiException(AuthFailure('بيانات غير صحيحة')),
      );
      final result = await LoginUseCase(repository)(
        username: 'a',
        password: 'b',
      );

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('يحوّل الاستثناءات غير المتوقعة إلى UnexpectedFailure', () async {
      final repository = _FakeAuthRepository(error: StateError('boom'));
      final result = await LoginUseCase(repository)(
        username: 'a',
        password: 'b',
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
