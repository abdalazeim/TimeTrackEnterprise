/// Role-aware portal state. Mirrors `PortalStore` from the reference app:
/// the phone can be signed in as a staff member (admin/employee) or as a
/// parent with one or more linked children.
class PortalSnapshot {
  const PortalSnapshot({
    this.mode = PortalMode.none,
    this.staff,
    this.children = const <PortalChild>[],
    this.alerts = false,
  });

  static const PortalSnapshot empty = PortalSnapshot();

  final String mode;
  final PortalStaff? staff;
  final List<PortalChild> children;
  final bool alerts;

  bool get hasStaff => staff != null && staff!.token.isNotEmpty;
  bool get hasChildren => children.isNotEmpty;
  bool get isParent => mode == PortalMode.parent && hasChildren;
  bool get isStaff => mode == PortalMode.staff && hasStaff;

  PortalSnapshot copyWith({
    String? mode,
    PortalStaff? staff,
    bool clearStaff = false,
    List<PortalChild>? children,
    bool? alerts,
  }) {
    return PortalSnapshot(
      mode: mode ?? this.mode,
      staff: clearStaff ? null : (staff ?? this.staff),
      children: children ?? this.children,
      alerts: alerts ?? this.alerts,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode,
        'staff': staff?.toJson(),
        'children': children.map((child) => child.toJson()).toList(),
        'alerts': alerts,
      };

  factory PortalSnapshot.fromJson(Map<String, Object?> json) {
    final rawChildren = json['children'];
    return PortalSnapshot(
      mode: (json['mode'] as String?) ?? PortalMode.none,
      staff: json['staff'] is Map
          ? PortalStaff.fromJson(
              (json['staff'] as Map).cast<String, Object?>(),
            )
          : null,
      children: rawChildren is List
          ? rawChildren
              .whereType<Map>()
              .map((item) =>
                  PortalChild.fromJson(item.cast<String, Object?>()))
              .toList(growable: false)
          : const <PortalChild>[],
      alerts: json['alerts'] as bool? ?? false,
    );
  }
}

class PortalMode {
  const PortalMode._();

  static const String none = 'none';
  static const String parent = 'parent';
  static const String staff = 'staff';
}

class PortalStaff {
  const PortalStaff({
    required this.serverUrl,
    required this.token,
    required this.role,
    required this.name,
    required this.username,
    required this.schoolName,
  });

  final String serverUrl;
  final String token;

  /// Backend role as entered by the user: `admin` or `employee`.
  final String role;
  final String name;
  final String username;
  final String schoolName;

  bool get isAdmin => role == 'admin';

  Map<String, Object?> toJson() => <String, Object?>{
        'server_url': serverUrl,
        'token': token,
        'role': role,
        'name': name,
        'username': username,
        'school_name': schoolName,
      };

  factory PortalStaff.fromJson(Map<String, Object?> json) {
    return PortalStaff(
      serverUrl: (json['server_url'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      schoolName: (json['school_name'] as String?) ?? '',
    );
  }
}

class PortalChild {
  const PortalChild({
    required this.id,
    required this.serverUrl,
    required this.token,
    required this.nin,
    required this.name,
    required this.classGroup,
    required this.schoolName,
    required this.cursor,
  });

  final String id;
  final String serverUrl;
  final String token;
  final String nin;
  final String name;
  final String classGroup;
  final String schoolName;
  final int cursor;

  PortalChild copyWith({int? cursor}) {
    return PortalChild(
      id: id,
      serverUrl: serverUrl,
      token: token,
      nin: nin,
      name: name,
      classGroup: classGroup,
      schoolName: schoolName,
      cursor: cursor ?? this.cursor,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'server_url': serverUrl,
        'token': token,
        'nin': nin,
        'name': name,
        'class_group': classGroup,
        'school_name': schoolName,
        'cursor': cursor,
      };

  factory PortalChild.fromJson(Map<String, Object?> json) {
    return PortalChild(
      id: (json['id'] as String?) ?? '',
      serverUrl: (json['server_url'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      nin: (json['nin'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      classGroup: (json['class_group'] as String?) ?? '',
      schoolName: (json['school_name'] as String?) ?? '',
      cursor: (json['cursor'] as num?)?.toInt() ?? 0,
    );
  }
}
