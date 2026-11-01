import 'dart:io';

/// Identifiers and protocol constants shared by the gateway and companion.
class GatewayInfo {
  const GatewayInfo._();

  static const String appName = 'TimeTrackEnterprise';
  static const String gatewayName = 'TimeTrackEnterprise Gateway';
  static const String version = '4.1.1';
  static const String userAgent = 'SmartAttendanceGateway/$version';
  static const String lanDiscoveryQuery = 'SMARTATTENDANCE?';
  static const int lanDiscoveryPort = 8866;
  static const String scansPath = '/scans';
  static const String sendPath = '/send';
}

/// A human readable device name. The web dashboard shows this in the device
/// approval list.
String deviceDisplayName() {
  final host = Platform.localHostname.trim();
  if (host.isNotEmpty && host.toLowerCase() != 'localhost') {
    return host;
  }
  if (Platform.isAndroid) return 'Android Device';
  if (Platform.isIOS) return 'iPhone';
  if (Platform.isWindows) return 'Windows Device';
  if (Platform.isMacOS) return 'Mac Device';
  if (Platform.isLinux) return 'Linux Device';
  return 'Attendance Device';
}
