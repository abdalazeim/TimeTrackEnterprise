import 'package:generic_template/core/auth/auth_tokens.dart';
import 'package:generic_template/core/auth/profile_store.dart';
import 'package:generic_template/core/auth/token_store.dart';

/// تخزين رموز في الذاكرة للاختبارات.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  AuthTokens? get current => _tokens;

  void set(AuthTokens? tokens) => _tokens = tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

/// ملف مستخدم في الذاكرة للاختبارات.
class InMemoryProfileStore implements ProfileStore {
  InMemoryProfileStore([this._profile]);

  Map<String, dynamic>? _profile;
  int? _userId;

  Map<String, dynamic>? get current => _profile;

  void setProfile(Map<String, dynamic>? profile, {int? userId}) {
    _profile = profile;
    _userId = userId;
  }

  @override
  Future<Map<String, dynamic>?> read({int? userId}) async =>
      userId != null && userId == _userId ? _profile : null;

  @override
  Future<void> write(Map<String, dynamic> profile, {int? userId}) async {
    _profile = profile;
    _userId = userId;
  }

  @override
  Future<void> clear() async {
    _profile = null;
    _userId = null;
  }
}
