import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/auth/session_manager.dart';
import 'package:generic_template/core/error/failure.dart';
import 'package:generic_template/core/network/api_client.dart';
import 'package:generic_template/core/network/failure_mapper.dart';
import 'package:generic_template/features/auth/data/datasources/auth_api.dart';
import 'package:generic_template/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:generic_template/features/auth/domain/entities/app_user.dart';
import 'package:generic_template/features/auth/domain/entities/auth_session.dart';

import '../../helpers/fakes.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(ApiClient(Dio()));

  AuthSession? loginResult;
  AppUser? meResult;
  Object? loginError;
  Object? meError;
  bool logoutFails = false;
  int logoutCalls = 0;
  String? lastRefresh;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return meResult!;
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    logoutCalls++;
    lastRefresh = refreshToken;
    if (logoutFails) {
      throw const ApiException(NetworkFailure('offline'));
    }
  }
}

void main() {
  const tokens = AuthTokens(access: 'access-1', refresh: 'refresh-1');
  const user = AppUser(id: 9, username: 'ahmed');
  const session = AuthSession(tokens: tokens, user: user);

  late _FakeAuthApi api;
  late InMemoryTokenStore tokenStore;
  late InMemoryProfileStore profileStore;
  late SessionManager sessionManager;
  late AuthRepositoryImpl repository;

  setUp(() async {
    api = _FakeAuthApi();
    tokenStore = InMemoryTokenStore();
    profileStore = InMemoryProfileStore();
    sessionManager = SessionManager(
      store: tokenStore,
      refreshTokens: (refresh) async {
        api.lastRefresh = refresh;
        return tokens;
      },
    );
    repository = AuthRepositoryImpl(
      api: api,
      session: sessionManager,
      profiles: profileStore,
    );
  });

  tearDown(() => sessionManager.dispose());

  test('الدخول يحفظ الرموز والملف الشخصي', () async {
    api.loginResult = session;

    final result = await repository.login(
      username: 'ahmed',
      password: 'secret',
    );

    expect(result.user, user);
    expect(tokenStore.current?.userId, user.id);
    expect(tokenStore.current?.access, tokens.access);
    expect(profileStore.current?['username'], 'ahmed');
    expect(sessionManager.hasTokens, isTrue);
  });

  test('لا توجد جلسة عند غياب الرموز', () async {
    api.meResult = user;

    expect(await repository.restoreSession(), isNull);
  });

  test('يستعيد الجلسة عبر /auth/me ويحدّث الملف المحفوظ', () async {
    tokenStore.set(tokens.copyWith(userId: user.id));
    api.meResult = user;

    final restored = await repository.restoreSession();

    expect(restored, user);
    expect(profileStore.current?['username'], 'ahmed');
    expect(tokenStore.current?.userId, user.id);
  });

  test('يعود للملف المحفوظ عند تعذر الشبكة', () async {
    tokenStore.set(tokens.copyWith(userId: user.id));
    profileStore.setProfile(
      <String, dynamic>{
        'id': 9,
        'username': 'cached-user',
      },
      userId: user.id,
    );
    api.meError = const ApiException(NetworkFailure('offline'));

    final restored = await repository.restoreSession();

    expect(restored?.username, 'cached-user');
    expect(
      tokenStore.current?.userId,
      user.id,
      reason: 'تبقى الجلسة للاستخدام offline',
    );
  });

  test('لا يستعيد ملف مستخدم مختلف عند تعذر الشبكة', () async {
    tokenStore.set(tokens.copyWith(userId: user.id));
    profileStore.setProfile(
      <String, dynamic>{
        'id': 10,
        'username': 'another-account',
      },
      userId: 10,
    );
    api.meError = const ApiException(NetworkFailure('offline'));

    await expectLater(
      repository.restoreSession(),
      throwsA(isA<ApiException>()),
    );
  });

  test('جلسة مرفوضة تُمسح ولا تعود للملف المحفوظ', () async {
    tokenStore.set(tokens.copyWith(userId: user.id));
    profileStore.setProfile(
      <String, dynamic>{
        'id': 9,
        'username': 'cached-user',
      },
      userId: user.id,
    );
    api.meError = const ApiException(AuthFailure('expired'));

    expect(await repository.restoreSession(), isNull);
    expect(tokenStore.current, isNull);
  });

  test('الخروج يمسح محليًا ويبلغ الخادم', () async {
    api.loginResult = session;
    await repository.login(username: 'ahmed', password: 'secret');

    await repository.logout();
    await Future<void>.delayed(Duration.zero);

    expect(tokenStore.current, isNull);
    expect(profileStore.current, isNull);
    expect(api.logoutCalls, 1);
    expect(api.lastRefresh, 'refresh-1');
  });

  test('فشل إبلاغ الخادم لا يمنع الخروج المحلي', () async {
    api.loginResult = session;
    await repository.login(username: 'ahmed', password: 'secret');
    api.logoutFails = true;

    await repository.logout();
    await Future<void>.delayed(Duration.zero);

    expect(tokenStore.current, isNull);
    expect(profileStore.current, isNull);
  });
}
