/// Session of a phone that has been paired with the desktop attendance
/// server. `deviceSecret` is issued by `/api/mobile/login-code` and is used
/// to refresh the session through `/api/mobile/devices/session`.
class CompanionSession {
  const CompanionSession({
    this.serverUrl = '',
    this.token = '',
    this.username = '',
    this.displayName = '',
    this.roleLabel = '',
    this.schoolName = '',
    this.deviceSecret = '',
    this.deviceStatus = '',
    this.pairCode = '',
  });

  static const CompanionSession empty = CompanionSession();

  final String serverUrl;
  final String token;
  final String username;
  final String displayName;
  final String roleLabel;
  final String schoolName;
  final String deviceSecret;
  final String deviceStatus;
  final String pairCode;

  bool get hasSession => token.isNotEmpty && serverUrl.isNotEmpty;
  bool get hasDeviceSecret => deviceSecret.isNotEmpty;
  bool get isPending => deviceStatus == 'pending';
  bool get isBlocked => deviceStatus == 'blocked';
  bool get isApproved =>
      deviceStatus == 'approved' && (hasSession || hasDeviceSecret);

  /// A short label suitable for headers and tiles.
  String get label {
    if (displayName.isNotEmpty) return displayName;
    if (username.isNotEmpty) return username;
    return 'Companion';
  }

  CompanionSession copyWith({
    String? serverUrl,
    String? token,
    String? username,
    String? displayName,
    String? roleLabel,
    String? schoolName,
    String? deviceSecret,
    String? deviceStatus,
    String? pairCode,
  }) {
    return CompanionSession(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      roleLabel: roleLabel ?? this.roleLabel,
      schoolName: schoolName ?? this.schoolName,
      deviceSecret: deviceSecret ?? this.deviceSecret,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      pairCode: pairCode ?? this.pairCode,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'server_url': serverUrl,
        'token': token,
        'username': username,
        'display_name': displayName,
        'role_label': roleLabel,
        'school_name': schoolName,
        'device_secret': deviceSecret,
        'device_status': deviceStatus,
        'pair_code': pairCode,
      };

  factory CompanionSession.fromJson(Map<String, Object?> json) {
    return CompanionSession(
      serverUrl: (json['server_url'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      displayName: (json['display_name'] as String?) ?? '',
      roleLabel: (json['role_label'] as String?) ?? '',
      schoolName: (json['school_name'] as String?) ?? '',
      deviceSecret: (json['device_secret'] as String?) ?? '',
      deviceStatus: (json['device_status'] as String?) ?? '',
      pairCode: (json['pair_code'] as String?) ?? '',
    );
  }
}
