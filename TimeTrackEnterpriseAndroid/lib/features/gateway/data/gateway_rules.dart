/// Validation rules shared by the portal, scanner setup and companion flows.
class PortalRules {
  const PortalRules._();

  static final RegExp _childCode = RegExp(r'^[0-9]{12}$');
  static final RegExp _phoneCode = RegExp(r'^[0-9]{8}$');
  static final RegExp _ipv4Part = RegExp(r'^(0|[1-9][0-9]{0,2})$');

  /// The backend uses `user` for employee accounts.
  static bool roleMatches(String entered, String backendRole) {
    if (entered == 'admin') return backendRole == 'admin';
    if (entered == 'employee') return backendRole == 'user';
    return false;
  }

  static bool isStaffRole(String role) => role == 'admin' || role == 'employee';

  static bool isChildCode(String? code) =>
      code != null && _childCode.hasMatch(code);

  static bool isPhoneCode(String? code) =>
      code != null && _phoneCode.hasMatch(code);

  /// Normalises a server address. HTTPS is allowed for public hosts; HTTP is
  /// restricted to LAN/localhost addresses, matching the reference app.
  static String? normalizeServer(String? input) {
    var value = input?.trim() ?? '';
    if (value.isEmpty) return null;
    try {
      if (!value.contains('://')) {
        final probe = Uri.tryParse('http://$value');
        final scheme = lanHost(probe?.host) ? 'http' : 'https';
        value = '$scheme://$value';
      }
      final uri = Uri.tryParse(value);
      if (uri == null) return null;
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return null;
      final host = uri.host;
      if (host.isEmpty) return null;
      if (uri.userInfo.isNotEmpty) return null;
      if (uri.hasQuery || uri.hasFragment) return null;
      if (uri.path.isNotEmpty && uri.path != '/') return null;
      if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
      if (scheme == 'http' && !lanHost(host)) return null;
      final buffer = StringBuffer('$scheme://${host.toLowerCase()}');
      if (uri.hasPort) buffer.write(':${uri.port}');
      return buffer.toString();
    } catch (_) {
      return null;
    }
  }

  static bool lanHost(String? host) {
    if (host == null) return false;
    var value = host.toLowerCase();
    if (value == 'localhost' || value == '[::1]' || value == '::1') {
      return true;
    }
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1);
    }
    if (value.contains(':') && RegExp(r'^[0-9a-f:]+$').hasMatch(value)) {
      return value.startsWith('fc') ||
          value.startsWith('fd') ||
          value.startsWith('fe80:');
    }
    final parts = value.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      if (!_ipv4Part.hasMatch(part)) return false;
      final octet = int.tryParse(part);
      if (octet == null || octet > 255) return false;
      octets.add(octet);
    }
    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        first == 127 ||
        (first == 192 && second == 168) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 169 && second == 254);
  }

  /// Accepts only 8-digit login codes displayed by the web dashboard.
  static String sanitizePasscode(String value) =>
      value.replaceAll(RegExp(r'\D'), '').trim();

  static String sanitizeChildCode(String value) =>
      value.replaceAll(RegExp(r'\D'), '').trim();
}
