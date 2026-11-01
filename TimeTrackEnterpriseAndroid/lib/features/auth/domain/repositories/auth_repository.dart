import '../entities/app_user.dart';
import '../entities/auth_session.dart';

abstract interface class AuthRepository {
  /// تسجيل الدخول وحفظ الرموز في التخزين الآمن.
  Future<AuthSession> login({
    required String username,
    required String password,
  });

  /// استعادة الجلسة عند الإقلاع. يعيد `null` إن لم توجد جلسة صالحة.
  Future<AppUser?> restoreSession();

  /// يمسح الجلسة محليًا (ويحاول إبلاغ الخادم دون أن يفشل الخروج).
  Future<void> logout();
}
