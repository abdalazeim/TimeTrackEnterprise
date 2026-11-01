import '../../../../core/auth/auth_tokens.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';

/// الاتصال الفعلي بمسارات المصادقة.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final payload = await _client.postMap(
      ApiEndpoints.login,
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
      authenticated: false,
    );

    final userJson = _userJson(payload);
    final user = AppUser.fromJson(userJson);
    final tokens = _tokensFrom(payload, fallbackRefresh: null).copyWith(
      userId: user.id,
      server: AppConfig.baseUrl,
    );
    return AuthSession(tokens: tokens, user: user);
  }

  /// يجدد الرموز. الخادم يدوّر `refresh` أيضًا، فنحتفظ بالجديد إن وُجد.
  Future<AuthTokens> refresh(String refreshToken) async {
    final payload = await _client.postMap(
      ApiEndpoints.refresh,
      body: <String, dynamic>{'refresh': refreshToken},
      authenticated: false,
    );
    return _tokensFrom(payload, fallbackRefresh: refreshToken).copyWith(
      server: AppConfig.baseUrl,
    );
  }

  /// الملف الشخصي الحالي — المسار بلا شرطة نهائية.
  Future<AppUser> me() async {
    final payload = await _client.getMap(ApiEndpoints.me);
    return AppUser.fromJson(_userJson(payload));
  }

  /// إبلاغ الخادم بالخروج (best effort). لا يفشل الخروج المحلي إن رفض الخادم.
  Future<void> logout({String? refreshToken}) async {
    final body = refreshToken == null
        ? null
        : <String, dynamic>{'refresh': refreshToken};
    await _client.postVoid(ApiEndpoints.logout, body: body);
  }

  AuthTokens _tokensFrom(
    Map<String, dynamic> payload, {
    required String? fallbackRefresh,
  }) {
    final access = payload['access']?.toString();
    final refresh = payload['refresh']?.toString() ?? fallbackRefresh;

    if (access == null || access.isEmpty) {
      throw const ApiException(
        ParseFailure('استجابة المصادقة لا تحتوي على access token.'),
      );
    }
    if (refresh == null || refresh.isEmpty) {
      throw const ApiException(
        ParseFailure('استجابة المصادقة لا تحتوي على refresh token.'),
      );
    }
    return AuthTokens(access: access, refresh: refresh);
  }

  Map<String, dynamic> _userJson(Map<String, dynamic> payload) {
    final nestedUser = payload['user'];
    if (nestedUser is Map) return nestedUser.cast<String, dynamic>();

    final nestedData = payload['data'];
    if (nestedData is Map) {
      final user = nestedData['user'];
      if (user is Map) return user.cast<String, dynamic>();
      return nestedData.cast<String, dynamic>();
    }
    return payload;
  }
}
