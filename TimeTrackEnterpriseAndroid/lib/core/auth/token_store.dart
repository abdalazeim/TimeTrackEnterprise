import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'auth_tokens.dart';

/// عقد تخزين رموز الدخول — يسمح بتبديل التنفيذ في الاختبارات.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// تخزين آمن على مستوى النظام (Keystore على أندرويد).
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _bundleKey = 'generic_template.session.v2';
  static const String _accessKey = 'generic_template.access_token';
  static const String _refreshKey = 'generic_template.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthTokens?> read() async {
    final bundle = await _storage.read(key: _bundleKey);
    if (bundle != null && bundle.isNotEmpty) {
      try {
        final decoded = jsonDecode(bundle);
        if (decoded is! Map) return null;
        final server = decoded['server']?.toString();
        if (server != AppConfig.baseUrl) {
          await clear();
          return null;
        }
        final access = decoded['access']?.toString();
        final refresh = decoded['refresh']?.toString();
        if (access == null || refresh == null) return null;
        final rawUserId = decoded['user_id'];
        final tokens = AuthTokens(
          access: access,
          refresh: refresh,
          userId: rawUserId is int ? rawUserId : int.tryParse('$rawUserId'),
          server: server,
        );
        return tokens.isValid ? tokens : null;
      } on FormatException {
        await clear();
        return null;
      }
    }

    // Migrate the original two-key format once. It has no known identity, so
    // offline profile restoration remains disabled until /auth/me succeeds.
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    final tokens = AuthTokens(
      access: access,
      refresh: refresh,
      server: AppConfig.baseUrl,
    );
    if (!tokens.isValid) return null;
    await write(tokens);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    return tokens;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    await _storage.write(
      key: _bundleKey,
      value: jsonEncode(<String, Object?>{
        'access': tokens.access,
        'refresh': tokens.refresh,
        'user_id': tokens.userId,
        'server': AppConfig.baseUrl,
      }),
    );
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _bundleKey);
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
