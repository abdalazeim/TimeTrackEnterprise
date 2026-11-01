import '../../../../core/auth/auth_tokens.dart';
import 'app_user.dart';

/// جلسة كاملة بعد تسجيل الدخول.
class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  final AuthTokens tokens;
  final AppUser user;
}
