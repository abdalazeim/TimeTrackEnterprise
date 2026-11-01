import 'dart:async';

import '../../../../core/auth/profile_store.dart';
import '../../../../core/auth/session_manager.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApi api,
    required SessionManager session,
    required ProfileStore profiles,
  })  : _api = api,
        _session = session,
        _profiles = profiles;

  final AuthApi _api;
  final SessionManager _session;
  final ProfileStore _profiles;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final result = await _api.login(username: username, password: password);
    final tokens = result.tokens.copyWith(
      userId: result.user.id,
      server: result.tokens.server ?? AppConfig.baseUrl,
    );
    await _session.save(tokens);
    await _profiles.write(result.user.toJson(), userId: result.user.id);
    return AuthSession(tokens: tokens, user: result.user);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final tokens = await _session.restore();
    if (tokens == null) return null;

    try {
      final user = await _api.me();
      await _session.bindIdentity(
        tokens.copyWith(userId: user.id, server: AppConfig.baseUrl),
      );
      await _profiles.write(user.toJson(), userId: user.id);
      return user;
    } on ApiException catch (error) {
      final failure = error.failure;

      // جلسة منتهية فعليًا — لا فائدة من إبقاء الرموز.
      if (failure is AuthFailure || failure is PermissionFailure) {
        await _session.expire(reason: failure.message);
        return null;
      }

      // تعذر الوصول للشبكة: نسمح بالدخول بالملف المحفوظ (Offline-First).
      final cached = tokens.userId == null
          ? null
          : await _profiles.read(userId: tokens.userId);
      if (cached != null) return AppUser.fromJson(cached);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = _session.tokens?.refresh;

    // الخروج المحلي فوري ولا ينتظر الخادم.
    await _session.signOut();
    await _profiles.clear();

    if (refreshToken == null || refreshToken.isEmpty) return;
    unawaited(_notifyServer(refreshToken));
  }

  Future<void> _notifyServer(String refreshToken) async {
    try {
      await _api.logout(refreshToken: refreshToken);
    } on ApiException {
      // إبلاغ الخادم تحسيني فقط — الجلسة أُلغيت محليًا بالفعل.
    }
  }
}
