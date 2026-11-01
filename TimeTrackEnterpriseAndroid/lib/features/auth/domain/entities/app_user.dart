/// مستخدم التطبيق كما يعيده الخادم.
///
/// لا يعتمد على `package:flutter` ولا على أي مكتبة خارجية.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String username;

  /// الحقول الأصلية كما وصلت — تُحفظ للاستخدام المستقبلي دون فقدان.
  final Map<String, dynamic> raw;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    final username = (json['username'] ?? json['name'] ?? '').toString();
    return AppUser(
      id: id,
      username: username.isEmpty ? 'مستخدم' : username,
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...raw,
        'id': id,
        'username': username,
      };

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.id == id && other.username == username;

  @override
  int get hashCode => Object.hash(id, username);

  @override
  String toString() => 'AppUser($id, $username)';
}
