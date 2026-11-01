import 'dart:async';
import 'dart:io';

import '../domain/entities/companion_session.dart';
import 'gateway_info.dart';
import 'gateway_mobile_api.dart';
import 'gateway_rules.dart';
import 'local/gateway_prefs.dart';

/// Outcome of a device session refresh.
class DevicePairingResult {
  const DevicePairingResult({
    this.approved = false,
    this.pending = false,
    this.blocked = false,
    this.offline = false,
    this.unknown = false,
    this.pairCode = '',
    this.deviceName = '',
    this.message = '',
  });

  final bool approved;
  final bool pending;
  final bool blocked;
  final bool offline;
  final bool unknown;
  final String pairCode;
  final String deviceName;
  final String message;

  bool get ok => approved;
}

/// Refreshes the companion device through `/api/mobile/devices/session`.
class DevicePairing {
  DevicePairing({
    required GatewayPrefs prefs,
    String? deviceName,
    MobileApi Function(String baseUrl)? apiFactory,
  })  : _prefs = prefs,
        _deviceName = deviceName ?? deviceDisplayName(),
        _apiFactory = apiFactory ??
            ((baseUrl) => MobileApi(baseUrl: baseUrl, version: GatewayInfo.version));

  final GatewayPrefs _prefs;
  final String _deviceName;
  final MobileApi Function(String baseUrl) _apiFactory;

  Future<DevicePairingResult> refresh() async {
    final portal = _prefs.portal();
    if (!portal.isStaff) {
      return const DevicePairingResult(unknown: true);
    }

    final companion = _prefs.companion();
    final base = PortalRules.normalizeServer(companion.serverUrl);
    if (base == null || companion.deviceSecret.isEmpty) {
      return const DevicePairingResult(unknown: true);
    }

    final api = _apiFactory(base);
    try {
      final response = await api.post(
        '/api/mobile/devices/session',
        <String, Object?>{
          'device_id': _prefs.deviceId,
          'secret': companion.deviceSecret,
          'device_name': _deviceName,
          'app_version': GatewayInfo.version,
        },
      );

      final user = _asMap(response['user']);
      final server = _asMap(response['server']);
      final device = _asMap(response['device']);
      final token = _string(response['token']);

      final updated = companion.copyWith(
        serverUrl: base,
        token: token,
        username: _string(user?['username'], companion.username),
        displayName: _string(user?['display_name'], companion.displayName),
        roleLabel: _string(user?['role_label'], companion.roleLabel),
        schoolName: _string(server?['school_name'], companion.schoolName),
        deviceStatus: 'approved',
        pairCode: '',
      );
      await _prefs.saveCompanion(updated);

      return DevicePairingResult(
        approved: true,
        deviceName: _string(device?['name']),
        message: 'Device approved',
      );
    } on MobileApiException catch (error) {
      if (error.code == 'device_pending') {
        final device = _asMap(error.body?['device']);
        final pairCode = _string(
          device?['pair_code'],
          companion.pairCode,
        );
        await _prefs.setCompanionStatus('pending', pairCode: pairCode);
        return DevicePairingResult(
          pending: true,
          pairCode: pairCode,
          deviceName: _string(device?['name']),
          message: error.message,
        );
      }
      if (error.code == 'device_blocked') {
        await _prefs.setCompanionStatus('blocked', pairCode: '');
        return DevicePairingResult(
          blocked: true,
          message: error.message,
        );
      }
      if (error.status == 401) {
        return DevicePairingResult(
          unknown: true,
          message: error.message,
        );
      }
      return DevicePairingResult(message: error.message);
    } on SocketException {
      return const DevicePairingResult(offline: true);
    } on TimeoutException {
      return const DevicePairingResult(offline: true);
    } on IOException {
      return const DevicePairingResult(offline: true);
    } catch (error) {
      return DevicePairingResult(message: error.toString());
    } finally {
      api.close();
    }
  }

  /// Rechecks the current pairing and updates local state.
  Future<CompanionSession> refreshSession() async {
    final result = await refresh();
    if (result.approved) return _prefs.companion();
    final current = _prefs.companion();
    if (result.pending) {
      return current.copyWith(deviceStatus: 'pending', pairCode: result.pairCode);
    }
    if (result.blocked) {
      return current.copyWith(deviceStatus: 'blocked');
    }
    return current;
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  static String _string(Object? value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }
}
