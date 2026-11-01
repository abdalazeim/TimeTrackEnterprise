/// زوج رموز الدخول. الخادم يدوّر `access` و`refresh` معًا.
class AuthTokens {
  const AuthTokens({
    required this.access,
    required this.refresh,
    this.userId,
    this.server,
  });

  final String access;
  final String refresh;
  final int? userId;
  final String? server;

  bool get isValid => access.isNotEmpty && refresh.isNotEmpty;

  AuthTokens copyWith({
    String? access,
    String? refresh,
    int? userId,
    String? server,
  }) =>
      AuthTokens(
        access: access ?? this.access,
        refresh: refresh ?? this.refresh,
        userId: userId ?? this.userId,
        server: server ?? this.server,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthTokens &&
      other.access == access &&
      other.refresh == refresh &&
      other.userId == userId &&
      other.server == server;

  @override
  int get hashCode => Object.hash(access, refresh, userId, server);

  @override
  String toString() => 'AuthTokens(access: ***, refresh: ***)';
}
