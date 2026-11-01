import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// يخزّن آخر ملف مستخدم معروف ليتيح فتح التطبيق بلا شبكة.
abstract interface class ProfileStore {
  Future<Map<String, dynamic>?> read({int? userId});

  Future<void> write(Map<String, dynamic> profile, {int? userId});

  Future<void> clear();
}

class SecureProfileStore implements ProfileStore {
  SecureProfileStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'generic_template.profile.v2';
  static const String _legacyKey = 'app.profile';

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, dynamic>?> read({int? userId}) async {
    // The legacy profile had no account/server identity, so it cannot be
    // restored safely after the identity-scoped format was introduced.
    await _storage.delete(key: _legacyKey);
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['server'] != AppConfig.baseUrl) {
        return null;
      }
      final storedUserId = decoded['user_id'];
      if (userId == null || storedUserId != userId) return null;
      final profile = decoded['profile'];
      return profile is Map ? profile.cast<String, dynamic>() : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> profile, {int? userId}) {
    if (userId == null) {
      throw ArgumentError.value(
        userId,
        'userId',
        'A profile requires an account identity.',
      );
    }
    return _storage
        .write(
          key: _key,
          value: jsonEncode(<String, Object?>{
            'server': AppConfig.baseUrl,
            'user_id': userId,
            'profile': profile,
          }),
        )
        .then((_) => _storage.delete(key: _legacyKey));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _legacyKey);
  }
}
