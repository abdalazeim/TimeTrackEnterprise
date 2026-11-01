import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../domain/entities/portal_snapshot.dart';
import 'gateway_info.dart';
import 'gateway_mobile_api.dart';
import 'gateway_rules.dart';
import 'local/gateway_prefs.dart';

/// Outcome of a portal sign-in attempt.
class PortalLoginResult {
  const PortalLoginResult({
    this.ok = false,
    this.code = '',
    this.message = '',
    this.staff,
    this.child,
  });

  final bool ok;
  final String code;
  final String message;
  final PortalStaff? staff;
  final PortalChild? child;
}

/// Outcome of a portal data request (dashboard, attendance, notifications).
class PortalDataResult {
  const PortalDataResult({
    this.ok = false,
    this.code = '',
    this.message = '',
    this.data = const <String, Object?>{},
  });

  final bool ok;
  final String code;
  final String message;
  final Map<String, Object?> data;
}

/// Handles the staff and parent portal sessions stored by [GatewayPrefs].
///
/// The endpoints match `PortalActivity.java`:
/// * staff: `POST /api/mobile/pair` then `POST /api/mobile/hello`
/// * parent: `POST /api/mobile/parent/login`
/// * staff data: `/api/mobile/portal/dashboard`
/// * parent data: `/api/mobile/parent/me` and `/api/mobile/parent/attendance`
class PortalService {
  PortalService({
    required GatewayPrefs prefs,
    String? deviceName,
    MobileApi Function(String baseUrl, String token)? apiFactory,
  })  : _prefs = prefs,
        _deviceName = deviceName ?? deviceDisplayName(),
        _apiFactory = apiFactory ??
            ((baseUrl, token) => MobileApi(
                  baseUrl: baseUrl,
                  token: token,
                  version: GatewayInfo.version,
                ));

  final GatewayPrefs _prefs;
  final String _deviceName;
  final MobileApi Function(String baseUrl, String token) _apiFactory;

  PortalSnapshot get snapshot => _prefs.portal();

  Future<PortalLoginResult> loginStaff({
    required String server,
    required String role,
    required String code,
  }) async {
    final base = PortalRules.normalizeServer(server);
    if (base == null) {
      return const PortalLoginResult(
        code: 'invalid_server',
        message: 'Invalid server address',
      );
    }
    if (!PortalRules.isStaffRole(role)) {
      return const PortalLoginResult(
        code: 'invalid_role',
        message: 'Choose admin or employee',
      );
    }
    final normalisedCode = PortalRules.sanitizePasscode(code);
    if (!PortalRules.isPhoneCode(normalisedCode)) {
      return const PortalLoginResult(
        code: 'invalid_code',
        message: 'The staff code must contain eight digits',
      );
    }

    final api = _apiFactory(base, '');
    try {
      final response = await api.post(
        '/api/mobile/pair',
        <String, Object?>{
          'device_id': _prefs.deviceId,
          'role': role,
          'code': normalisedCode,
          'device_name': _deviceName,
          'platform': 'android',
          'app_version': GatewayInfo.version,
        },
      );

      final token = _string(response['token']);
      final user = _asMap(response['user']);
      final serverInfo = _asMap(response['server']);
      final backendRole = _string(user?['role']);

      if (token.isEmpty || user == null) {
        return const PortalLoginResult(
          code: 'invalid_response',
          message: 'The server returned an incomplete session',
        );
      }
      if (!PortalRules.roleMatches(role, backendRole)) {
        return const PortalLoginResult(
          code: 'role_mismatch',
          message: 'The selected role does not match this account',
        );
      }

      final username = _string(user['username']);
      final staff = PortalStaff(
        serverUrl: base,
        token: token,
        role: role,
        name: _string(user['display_name'], username),
        username: username,
        schoolName: _string(serverInfo?['school_name']),
      );

      final current = _prefs.portal();
      final updated = current.copyWith(
        mode: PortalMode.staff,
        staff: staff,
        children: current.children,
      );
      await _prefs.savePortal(updated);

      await _greet(base);
      return PortalLoginResult(ok: true, staff: staff);
    } on MobileApiException catch (error) {
      return PortalLoginResult(
        code: error.code,
        message: error.message,
      );
    } on SocketException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } on TimeoutException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server did not respond',
      );
    } on IOException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } catch (error) {
      return PortalLoginResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<PortalLoginResult> loginParent({
    required String server,
    required String code,
  }) async {
    final base = PortalRules.normalizeServer(server);
    if (base == null) {
      return const PortalLoginResult(
        code: 'invalid_server',
        message: 'Invalid server address',
      );
    }
    final normalisedCode = PortalRules.sanitizeChildCode(code);
    if (!PortalRules.isChildCode(normalisedCode)) {
      return const PortalLoginResult(
        code: 'invalid_code',
        message: 'The child code must contain twelve digits',
      );
    }

    final api = _apiFactory(base, '');
    try {
      final response = await api.post(
        '/api/mobile/parent/login',
        <String, Object?>{
          'device_id': _prefs.deviceId,
          'code': normalisedCode,
        },
      );

      final token = _string(response['token']);
      final parent = _asMap(response['parent']);
      final serverInfo = _asMap(response['server']);
      final nin = _string(parent?['student_nin']);
      if (token.isEmpty || parent == null || nin.isEmpty) {
        return const PortalLoginResult(
          code: 'invalid_response',
          message: 'The server returned an incomplete session',
        );
      }

      final current = _prefs.portal();
      final existing = current.children.where(
        (child) => child.serverUrl == base && child.nin == nin,
      );
      final id = existing.isEmpty ? const Uuid().v4() : existing.first.id;
      final child = PortalChild(
        id: id,
        serverUrl: base,
        token: token,
        nin: nin,
        name: _string(parent['full_name']),
        classGroup: _string(parent['class_group']),
        schoolName: _string(serverInfo?['school_name']),
        cursor: existing.isEmpty ? 0 : existing.first.cursor,
      );

      final children = <PortalChild>[
        ...current.children.where((item) => item.id != id),
        child,
      ];
      await _prefs.savePortal(
        current.copyWith(
          mode: PortalMode.parent,
          clearStaff: true,
          children: children,
        ),
      );
      return PortalLoginResult(ok: true, child: child);
    } on MobileApiException catch (error) {
      return PortalLoginResult(code: error.code, message: error.message);
    } on SocketException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } on TimeoutException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server did not respond',
      );
    } on IOException {
      return const PortalLoginResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } catch (error) {
      return PortalLoginResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<void> removeChild(String childId) async {
    final current = _prefs.portal();
    final children =
        current.children.where((child) => child.id != childId).toList();
    await _prefs.savePortal(
      current.copyWith(
        mode: children.isEmpty ? PortalMode.none : current.mode,
        children: children,
      ),
    );
  }

  Future<void> logout() => _prefs.clearPortal();

  Future<PortalDataResult> staffDashboard() async {
    final staff = _prefs.portal().staff;
    if (staff == null || staff.token.isEmpty) {
      return const PortalDataResult(
        code: 'no_session',
        message: 'Sign in as staff first',
      );
    }
    return _get(staff.serverUrl, staff.token, '/api/mobile/portal/dashboard',
        unwrap: 'dashboard');
  }

  Future<PortalDataResult> parentData(PortalChild child) async {
    final api = _apiFactory(child.serverUrl, child.token);
    try {
      final me = await api.get('/api/mobile/parent/me');
      final attendance = await api.get(
        '/api/mobile/parent/attendance',
        <String, String>{'days': '30'},
      );
      return PortalDataResult(
        ok: true,
        data: <String, Object?>{
          'me': me,
          'attendance': attendance,
        },
      );
    } on MobileApiException catch (error) {
      return PortalDataResult(code: error.code, message: error.message);
    } on SocketException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } on TimeoutException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server did not respond',
      );
    } on IOException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } catch (error) {
      return PortalDataResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<PortalDataResult> parentNotifications(PortalChild child) async {
    final since = child.cursor <= 0 ? '0' : child.cursor.toString();
    return _get(
      child.serverUrl,
      child.token,
      '/api/mobile/parent/notifications',
      query: <String, String>{'since_id': since},
    );
  }

  Future<PortalDataResult> markNotificationsRead(
    PortalChild child,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const PortalDataResult(ok: true);
    final api = _apiFactory(child.serverUrl, child.token);
    try {
      final data = await api.post(
        '/api/mobile/parent/notifications/read',
        <String, Object?>{'ids': ids},
      );
      return PortalDataResult(ok: true, data: data);
    } on MobileApiException catch (error) {
      return PortalDataResult(code: error.code, message: error.message);
    } catch (error) {
      return PortalDataResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<PortalDataResult> _get(
    String server,
    String token,
    String path, {
    Map<String, String>? query,
    String? unwrap,
  }) async {
    final base = PortalRules.normalizeServer(server);
    if (base == null) {
      return const PortalDataResult(
        code: 'invalid_server',
        message: 'Invalid server address',
      );
    }
    final api = _apiFactory(base, token);
    try {
      final response = await api.get(path, query);
      if (unwrap != null && response[unwrap] is Map) {
        return PortalDataResult(
          ok: true,
          data: (response[unwrap] as Map).cast<String, Object?>(),
        );
      }
      return PortalDataResult(ok: true, data: response);
    } on MobileApiException catch (error) {
      return PortalDataResult(code: error.code, message: error.message);
    } on SocketException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } on TimeoutException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server did not respond',
      );
    } on IOException {
      return const PortalDataResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } catch (error) {
      return PortalDataResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<void> _greet(String base) async {
    final api = _apiFactory(base, '');
    try {
      await api.post(
        '/api/mobile/hello',
        <String, Object?>{
          'device_id': _prefs.deviceId,
          'device_name': _deviceName,
          'platform': 'android',
          'app_version': GatewayInfo.version,
        },
      );
    } catch (_) {
      // Registration with `/api/mobile/hello` is best effort.
    } finally {
      api.close();
    }
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
