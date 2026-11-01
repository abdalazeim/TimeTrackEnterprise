import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/companion_session.dart';
import '../../domain/entities/gateway_settings.dart';
import '../../domain/entities/portal_snapshot.dart';

/// Persistent storage for the gateway, companion and portal state.
///
/// The reference Android application used three `SharedPreferences` files:
/// `gateway_prefs`, `portal_preferences` and `portal_vault`. The Flutter port
/// keeps the same logical separation in one preference store, prefixed per
/// area. Sensitive session tokens are supplied by the server and the device
/// already protects the app sandbox; they are never written to logs.
class GatewayPrefs {
  GatewayPrefs(this._prefs);

  static Future<GatewayPrefs> load() async =>
      GatewayPrefs(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const String _port = 'gateway.port';
  static const String _apiKey = 'gateway.api_key';
  static const String _pairPin = 'gateway.pair_pin';
  static const String _deviceId = 'gateway.device_id';
  static const String _autoStart = 'gateway.auto_start';
  static const String _keepAwake = 'gateway.keep_awake';
  static const String _shouldRun = 'gateway.should_run';
  static const String _companion = 'gateway.companion';
  static const String _portal = 'gateway.portal';
  static const String _introduced = 'gateway.introduced';
  static const String _pcSeen = 'gateway.pc_seen';
  static const String _language = 'gateway.language';

  // ---------------------------------------------------------------------
  // Gateway settings
  // ---------------------------------------------------------------------

  GatewaySettings settings() {
    final port = _prefs.getInt(_port) ?? GatewaySettings.defaultPort;
    return GatewaySettings(
      port:
          port < GatewaySettings.minPort || port > GatewaySettings.maxPort
              ? GatewaySettings.defaultPort
              : port,
      apiKey: apiKey,
      pairPin: pairPin,
      deviceId: deviceId,
      autoStart: _prefs.getBool(_autoStart) ?? false,
      keepAwake: _prefs.getBool(_keepAwake) ?? true,
    );
  }

  String get apiKey {
    final existing = _prefs.getString(_apiKey);
    if (existing != null) return existing;
    final generated = generateApiKey();
    _prefs.setString(_apiKey, generated);
    return generated;
  }

  String get pairPin {
    final existing = _prefs.getString(_pairPin);
    if (existing != null && RegExp(r'^\d{4}$').hasMatch(existing)) {
      return existing;
    }
    final generated = generatePin();
    _prefs.setString(_pairPin, generated);
    return generated;
  }

  String get deviceId {
    final existing = _prefs.getString(_deviceId);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9._:-]{8,64}$').hasMatch(existing)) {
      return existing;
    }
    final generated = generateDeviceId();
    _prefs.setString(_deviceId, generated);
    return generated;
  }

  bool get shouldRun => _prefs.getBool(_shouldRun) ?? false;

  bool get introduced => _prefs.getBool(_introduced) ?? false;

  String? get pcSeen => _prefs.getString(_pcSeen);

  String get language => _prefs.getString(_language) ?? 'ar';

  Future<void> setPort(int port) async {
    if (port < GatewaySettings.minPort || port > GatewaySettings.maxPort) {
      throw ArgumentError.value(port, 'port', 'Port must be between 1024 and 65535');
    }
    await _prefs.setInt(_port, port);
  }

  Future<void> setApiKey(String value) =>
      _prefs.setString(_apiKey, value.trim());

  Future<void> setPairPin(String value) async {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      throw ArgumentError.value(value, 'pin', 'Pairing PIN must be four digits');
    }
    await _prefs.setString(_pairPin, trimmed);
  }

  Future<void> setAutoStart(bool value) => _prefs.setBool(_autoStart, value);

  Future<void> setKeepAwake(bool value) => _prefs.setBool(_keepAwake, value);

  Future<void> setShouldRun(bool value) => _prefs.setBool(_shouldRun, value);

  Future<void> setIntroduced(bool value) => _prefs.setBool(_introduced, value);

  Future<void> setPcSeen(String value) => _prefs.setString(_pcSeen, value);

  Future<void> setLanguage(String value) => _prefs.setString(_language, value);

  Future<void> saveSettings(GatewaySettings settings) async {
    await _prefs.setInt(_port, settings.port);
    await _prefs.setString(_apiKey, settings.apiKey.trim());
    await _prefs.setString(_pairPin, settings.pairPin.trim());
    await _prefs.setString(_deviceId, settings.deviceId);
    await _prefs.setBool(_autoStart, settings.autoStart);
    await _prefs.setBool(_keepAwake, settings.keepAwake);
  }

  // ---------------------------------------------------------------------
  // Companion session
  // ---------------------------------------------------------------------

  CompanionSession companion() {
    final raw = _prefs.getString(_companion);
    if (raw == null || raw.isEmpty) return CompanionSession.empty;
    try {
      return CompanionSession.fromJson(
        Map<String, Object?>.from(_decodeMap(raw)),
      );
    } catch (_) {
      return CompanionSession.empty;
    }
  }

  Future<void> saveCompanion(CompanionSession session) =>
      _prefs.setString(_companion, _encodeMap(session.toJson()));

  Future<void> setCompanionStatus(String status, {String? pairCode}) async {
    final current = companion();
    await saveCompanion(
      current.copyWith(
        deviceStatus: status,
        pairCode: pairCode ?? current.pairCode,
      ),
    );
  }

  Future<void> forgetCompanionDevice() async {
    final current = companion();
    await saveCompanion(
      current.copyWith(deviceSecret: '', deviceStatus: '', pairCode: ''),
    );
  }

  Future<void> clearCompanion() => _prefs.remove(_companion);

  // ---------------------------------------------------------------------
  // Portal state
  // ---------------------------------------------------------------------

  PortalSnapshot portal() {
    final raw = _prefs.getString(_portal);
    if (raw == null || raw.isEmpty) return PortalSnapshot.empty;
    try {
      return PortalSnapshot.fromJson(
        Map<String, Object?>.from(_decodeMap(raw)),
      );
    } catch (_) {
      return PortalSnapshot.empty;
    }
  }

  Future<void> savePortal(PortalSnapshot snapshot) =>
      _prefs.setString(_portal, _encodeMap(snapshot.toJson()));

  Future<void> clearPortal() => _prefs.remove(_portal);

  // ---------------------------------------------------------------------
  // Generators
  // ---------------------------------------------------------------------

  static final Random _random = Random.secure();

  /// Generates the same 32 character hexadecimal key as the reference app.
  static String generateApiKey() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String generatePin() => _random.nextInt(10000).toString().padLeft(4, '0');

  static String generateDeviceId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

// JSON helpers kept private to this file.
Map<String, Object?> _decodeMap(String raw) {
  return jsonDecode(raw) as Map<String, Object?>;
}

String _encodeMap(Map<String, Object?> value) => jsonEncode(value);
