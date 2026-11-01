import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/entities/companion_session.dart';
import '../domain/entities/gateway_settings.dart';
import '../domain/entities/offline_scan.dart';
import '../domain/entities/portal_snapshot.dart';
import '../domain/entities/gateway_runtime.dart';
import 'device_pairing.dart';
import 'gateway_http_server.dart';
import 'gateway_info.dart';
import 'gateway_mobile_api.dart';
import 'gateway_rules.dart';
import 'lan_discovery.dart';
import 'local/gateway_prefs.dart';
import 'local/offline_store.dart';
import 'local/scan_queue.dart';
import 'offline_sync.dart';
import 'portal_service.dart';
import 'sms_sender.dart';

/// Raised for expected gateway configuration or session problems.
class GatewayException implements Exception {
  const GatewayException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Outcome of a `/api/mobile/login-code` scanner sign-in.
class ScannerConnectResult {
  const ScannerConnectResult({
    this.ok = false,
    this.pending = false,
    this.blocked = false,
    this.code = '',
    this.message = '',
    this.pairCode = '',
    this.companion = CompanionSession.empty,
  });

  final bool ok;
  final bool pending;
  final bool blocked;
  final String code;
  final String message;
  final String pairCode;
  final CompanionSession companion;
}

/// Orchestrates the local gateway, the companion session, the offline roster
/// and the portal. Presentation layers only talk to this service (through the
/// Riverpod controller) so every platform dependency stays in one place.
class GatewayService {
  GatewayService({
    GatewayPrefs? prefs,
    ScanQueue? scans,
    OfflineStore? store,
    SmsSender? smsSender,
    PortalService? portalService,
    LanDiscovery? discovery,
    DevicePairing? pairing,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        scans = scans ?? ScanQueue(clock: clock),
        store = store ?? OfflineStore(clock: clock),
        _smsSender = smsSender ?? SmsSender(),
        _portal = portalService,
        _discovery = discovery ?? const LanDiscovery(),
        _pairing = pairing,
        _clock = clock ?? DateTime.now;

  static const int maxApiKeyLength = 128;

  GatewayPrefs? _prefs;
  final ScanQueue scans;
  final OfflineStore store;
  final SmsSender _smsSender;
  final PortalService? _portal;
  final LanDiscovery _discovery;
  final DevicePairing? _pairing;
  final DateTime Function() _clock;

  GatewayHttpServer? _server;
  GatewayRuntime _runtime = const GatewayRuntime();
  GatewaySettings _settings = const GatewaySettings(
    port: GatewaySettings.defaultPort,
    apiKey: '',
    pairPin: '',
    deviceId: '',
    autoStart: true,
    keepAwake: true,
  );
  String _ip = '0.0.0.0';
  bool _initialized = false;
  bool _syncing = false;

  GatewaySettings get settings => _settings;
  GatewayRuntime get runtime => _runtime;
  CompanionSession get companion =>
      _prefs?.companion() ?? CompanionSession.empty;
  PortalSnapshot get portal => _prefs?.portal() ?? PortalSnapshot.empty;
  String get ip => _ip;
  String get deviceId => _settings.deviceId;
  bool get initialized => _initialized;
  bool get syncing => _syncing;

  String get serverAddress =>
      _ip == '0.0.0.0' || _ip.isEmpty ? '' : 'http://${_ip}:${_settings.port}';

  GatewayPrefs get _storePrefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('GatewayService.load() has not been called');
    }
    return prefs;
  }

  PortalService get portalService =>
      _portal ?? PortalService(prefs: _storePrefs);

  DevicePairing get _devicePairing =>
      _pairing ?? DevicePairing(prefs: _storePrefs);

  Future<void> load() async {
    if (_initialized) return;
    _prefs = _prefs ?? await GatewayPrefs.load();
    _settings = _prefs!.settings();
    _ip = await detectIp();
    _runtime = _runtime.copyWith(port: _settings.port);
    _initialized = true;

    if (_prefs!.shouldRun || _settings.autoStart) {
      try {
        await start();
      } catch (_) {
        // Auto-start failures are surfaced through `runtime.error`.
      }
    }
  }

  Future<String> detectIp() async {
    // Android can identify the active Wi-Fi/Ethernet route directly. Prefer it
    // over enumerating every interface, which may include VPN and virtual NICs.
    try {
      final active = await const MethodChannel('timetrack/network')
          .invokeMapMethod<String, String>('activeIpv4');
      final address = active?['ipv4'];
      if (address != null && _isUsableIpv4(address)) return address;
    } on PlatformException catch (_) {
      // Fall back to the interface list below.
    } on MissingPluginException catch (_) {
      // The native route channel is Android-only.
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final candidates =
          <({int interfaceRank, int addressRank, String address})>[];
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (RegExp(r'^(tun|tap|wg|ppp|rmnet|ccmni|veth|docker|lo)')
            .hasMatch(name)) {
          continue;
        }
        final interfaceRank =
            RegExp(r'^(wlan|wifi|wi-fi|eth|en\d|ethernet)').hasMatch(name)
                ? 0
                : 1;
        for (final address in interface.addresses) {
          if (address.type != InternetAddressType.IPv4 ||
              address.isLoopback ||
              address.isLinkLocal ||
              address.rawAddress.first >= 224) {
            continue;
          }
          candidates.add((
            interfaceRank: interfaceRank,
            addressRank: _isPrivateLanAddress(address) ? 0 : 1,
            address: address.address,
          ));
        }
      }
      candidates.sort((a, b) {
        final adapter = a.interfaceRank.compareTo(b.interfaceRank);
        if (adapter != 0) return adapter;
        final privateAddress = a.addressRank.compareTo(b.addressRank);
        if (privateAddress != 0) return privateAddress;
        return a.address.compareTo(b.address);
      });
      if (candidates.isNotEmpty) return candidates.first.address;
    } catch (_) {
      // Fall back to the no-address state below.
    }
    return '0.0.0.0';
  }

  bool _isUsableIpv4(String value) {
    final address = InternetAddress.tryParse(value);
    return address != null &&
        address.type == InternetAddressType.IPv4 &&
        !address.isLoopback &&
        !address.isLinkLocal &&
        address.rawAddress.first < 224;
  }

  bool _isPrivateLanAddress(InternetAddress address) {
    final octets = address.rawAddress;
    if (octets.length != 4) return false;
    return octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168);
  }

  Future<void> refreshIp() async {
    _ip = await detectIp();
  }

  Future<void> start() async {
    if (_runtime.running || _runtime.starting) return;
    final prefs = _storePrefs;
    _runtime = _runtime.copyWith(
      starting: true,
      clearError: true,
      port: _settings.port,
    );

    final server = GatewayHttpServer(
      port: _settings.port,
      apiKey: _settings.apiKey,
      pairPin: _settings.pairPin,
      scans: scans,
      smsHandler: _sendSms,
      onPcSeen: (userAgent) {
        unawaited(prefs.setPcSeen(_nowStamp()));
      },
      clock: _clock,
    );

    try {
      await server.start();
      _server = server;
      final startedAt = _clock();
      _runtime = _runtime.copyWith(
        running: true,
        starting: false,
        startedAt: startedAt,
        clearError: true,
        port: _settings.port,
      );
      await prefs.setShouldRun(true);
      if (_settings.keepAwake) await _setKeepAwake(true);
    } on SocketException catch (error) {
      _server = null;
      _runtime = _runtime.copyWith(
        running: false,
        starting: false,
        error:
            'Port ${_settings.port} is already in use (${error.osError?.message ?? 'bind failed'})',
      );
      rethrow;
    } catch (error) {
      _server = null;
      _runtime = _runtime.copyWith(
        running: false,
        starting: false,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
    await _storePrefs.setShouldRun(false);
    await _setKeepAwake(false);
    _runtime = _runtime.copyWith(
      running: false,
      starting: false,
      clearStartedAt: true,
      clearError: true,
    );
  }

  Future<void> restart() async {
    if (_runtime.running) await stop();
    await start();
  }

  Future<void> applySettings(GatewaySettings next) async {
    final prefs = _storePrefs;
    if (next.port < GatewaySettings.minPort ||
        next.port > GatewaySettings.maxPort) {
      throw const GatewayException(
        'invalid_port',
        'Port must be between 1024 and 65535',
      );
    }
    final pin = next.pairPin.trim();
    if (pin.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const GatewayException(
        'invalid_pin',
        'Pairing PIN must contain exactly four digits',
      );
    }
    final key = next.apiKey.trim();
    if (key.isNotEmpty && (key.length < 8 || key.length > maxApiKeyLength)) {
      throw const GatewayException(
        'invalid_key',
        'API key must contain between 8 and 128 characters',
      );
    }

    final normalised = next.copyWith(
      port: next.port,
      apiKey: key,
      pairPin: pin,
      deviceId: _settings.deviceId,
    );
    await prefs.saveSettings(normalised);
    final wasRunning = _runtime.running;
    _settings = normalised;
    _runtime = _runtime.copyWith(port: normalised.port);
    if (wasRunning) {
      await stop();
      await start();
    }
  }

  Future<void> setAutoStart(bool value) async {
    await _storePrefs.setAutoStart(value);
    _settings = _settings.copyWith(autoStart: value);
  }

  Future<void> _setKeepAwake(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // The local HTTP gateway remains available if the screen lock fails.
    }
  }

  Future<void> setKeepAwake(bool value) async {
    await _storePrefs.setKeepAwake(value);
    _settings = _settings.copyWith(keepAwake: value);
    if (_runtime.running) await _setKeepAwake(value);
  }

  Future<void> regenerateApiKey() async {
    final key = GatewayPrefs.generateApiKey();
    await applySettings(_settings.copyWith(apiKey: key));
  }

  Future<void> regeneratePairPin() async {
    final pin = GatewayPrefs.generatePin();
    await applySettings(_settings.copyWith(pairPin: pin));
  }

  Future<bool> setPairingEnabled(bool enabled) async {
    if (enabled) {
      final pin = _settings.pairPin.isEmpty
          ? GatewayPrefs.generatePin()
          : _settings.pairPin;
      await applySettings(_settings.copyWith(pairPin: pin));
      return true;
    }
    await _storePrefs.setPairPin('');
    await applySettings(_settings.copyWith(pairPin: ''));
    return false;
  }

  void clearScans() => scans.clear();

  int addGatewayScan(String code) => scans.add(code);

  Future<OfflineStats> stats() => store.stats();

  Future<List<QueuedScan>> recent([int limit = 8]) => store.recent(limit);

  Future<int> pendingOfflineCount() => store.pendingCount();

  Future<bool> hasRoster() => store.hasRoster();

  Future<String> schoolName() => store.schoolName();

  Future<String> rosterVersion() => store.rosterVersion();

  Future<String> lastRosterSync() => store.rosterSyncedAt();

  Future<String> lastSync() => store.lastSyncAt();

  ScanVerdict? lastOfflineScan;

  Future<ScanVerdict> scanOffline(String code) async {
    final portal = _storePrefs.portal();
    if (!portal.isStaff) {
      throw const GatewayException(
        'staff_required',
        'Sign in through the Companion Portal as staff before scanning attendance',
      );
    }
    final companion = _storePrefs.companion();
    final approved = companion.hasSession &&
        (companion.deviceSecret.isEmpty || companion.isApproved);
    if (!approved) {
      throw const GatewayException(
        'scanner_required',
        'Connect the scanner from Scanner Setup first',
      );
    }
    if (!await store.hasRoster()) {
      throw const GatewayException(
        'roster_required',
        'The offline roster has not been downloaded yet',
      );
    }
    final verdict = await store.scan(code);
    lastOfflineScan = verdict;
    return verdict;
  }

  Future<OfflineSyncResult> syncOffline() async {
    if (_syncing) {
      return const OfflineSyncResult(message: 'Sync already running');
    }
    _syncing = true;
    try {
      final sync = OfflineSync(
        prefs: _storePrefs,
        store: store,
        pairing: _devicePairing,
      );
      return await sync.run();
    } finally {
      _syncing = false;
    }
  }

  Future<DevicePairingResult> refreshCompanion() => _devicePairing.refresh();

  Future<ScannerConnectResult> connectScanner({
    required String server,
    required String passcode,
  }) async {
    final base = PortalRules.normalizeServer(server);
    if (base == null) {
      return const ScannerConnectResult(
        code: 'invalid_server',
        message: 'Invalid server address',
      );
    }
    final code = PortalRules.sanitizePasscode(passcode);
    if (!PortalRules.isPhoneCode(code)) {
      return const ScannerConnectResult(
        code: 'invalid_code',
        message: 'The scanner passcode must contain eight digits',
      );
    }

    final prefs = _storePrefs;
    final api = MobileApi(baseUrl: base, version: GatewayInfo.version);
    try {
      final response = await api.post(
        '/api/mobile/login-code',
        <String, Object?>{
          'device_id': prefs.deviceId,
          'device_name': deviceDisplayName(),
          'platform': 'android',
          'app_version': GatewayInfo.version,
          'passcode': code,
        },
      );

      final token = _string(response['token']);
      final secret = _string(response['device_secret']);
      final device = _asMap(response['device']);
      final user = _asMap(response['user']);
      final serverInfo = _asMap(response['server']);
      final approvalRequired = response['approval_required'] == true;

      var status = _string(device?['status']);
      if (status.isEmpty) status = 'approved';
      final pairCode = _string(device?['pair_code']);
      final username = _string(user?['username']);
      final displayName = _string(user?['display_name'], username);
      final roleLabel = _string(user?['role_label']);
      final schoolName = _string(serverInfo?['school_name']);

      if (token.isEmpty) {
        return const ScannerConnectResult(
          code: 'invalid_response',
          message: 'The server returned an incomplete scanner session',
        );
      }

      final previous = prefs.companion();
      final session = CompanionSession(
        serverUrl: base,
        token: token,
        username: username,
        displayName: displayName,
        roleLabel: roleLabel,
        schoolName: schoolName,
        deviceSecret: secret,
        deviceStatus: status,
        pairCode: pairCode,
      );
      await prefs.saveCompanion(
        session.copyWith(
          schoolName: schoolName.isEmpty ? previous.schoolName : schoolName,
        ),
      );

      // A scanner device sign-in carries the same staff identity. Persisting a
      // matching portal staff session lets SMS sending and offline syncing work
      // immediately after pairing.
      final backendRole = _string(user?['role']);
      if (backendRole == 'admin' || backendRole == 'user') {
        final enteredRole = backendRole == 'admin' ? 'admin' : 'employee';
        final current = prefs.portal();
        if (!current.isStaff) {
          await prefs.savePortal(
            current.copyWith(
              mode: PortalMode.staff,
              staff: PortalStaff(
                serverUrl: base,
                token: token,
                role: enteredRole,
                name: displayName,
                username: username,
                schoolName: schoolName,
              ),
            ),
          );
        }
      }

      if (status == 'blocked') {
        return ScannerConnectResult(
          blocked: true,
          code: 'device_blocked',
          message: 'This device has been blocked by the administrator',
          companion: session,
        );
      }
      if (approvalRequired || status == 'pending') {
        return ScannerConnectResult(
          pending: true,
          code: 'device_pending',
          message: 'Waiting for the administrator to approve this device',
          pairCode: pairCode,
          companion: session,
        );
      }

      return ScannerConnectResult(
        ok: true,
        code: 'ok',
        message: 'Scanner connected',
        companion: session,
      );
    } on MobileApiException catch (error) {
      return ScannerConnectResult(code: error.code, message: error.message);
    } on SocketException {
      return const ScannerConnectResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } on TimeoutException {
      return const ScannerConnectResult(
        code: 'offline',
        message: 'The server did not respond',
      );
    } on IOException {
      return const ScannerConnectResult(
        code: 'offline',
        message: 'The server is unreachable',
      );
    } catch (error) {
      return ScannerConnectResult(code: 'error', message: error.toString());
    } finally {
      api.close();
    }
  }

  Future<void> disconnectScanner() => _storePrefs.forgetCompanionDevice();

  Future<void> forgetScanner() async {
    await _storePrefs.clearCompanion();
    await store.close();
  }

  Future<String?> discoverServer([
    Duration timeout = const Duration(milliseconds: 2500),
  ]) =>
      _discovery.find(timeout);

  Future<PortalLoginResult> loginStaff({
    required String server,
    required String role,
    required String code,
  }) async {
    final result = await portalService.loginStaff(
      server: server,
      role: role,
      code: code,
    );
    if (result.ok) {
      // A new staff session makes the gateway sendable again.
      _settings = _storePrefs.settings();
    }
    return result;
  }

  Future<PortalLoginResult> loginParent({
    required String server,
    required String code,
  }) =>
      portalService.loginParent(server: server, code: code);

  Future<void> removeChild(String childId) =>
      portalService.removeChild(childId);

  Future<void> logoutPortal() => portalService.logout();

  Future<PortalDataResult> staffDashboard() => portalService.staffDashboard();

  Future<PortalDataResult> parentData(PortalChild child) =>
      portalService.parentData(child);

  Future<PortalDataResult> parentNotifications(PortalChild child) =>
      portalService.parentNotifications(child);

  Future<PortalDataResult> markNotificationsRead(
    PortalChild child,
    List<int> ids,
  ) =>
      portalService.markNotificationsRead(child, ids);

  Future<SmsResult> _sendSms(String phone, String message) {
    if (!_storePrefs.portal().isStaff) {
      return Future<SmsResult>.value(
        const SmsResult(
          false,
          'A staff portal session is required to send SMS',
        ),
      );
    }
    return _smsSender.send(phone, message);
  }

  Future<SmsResult> sendSms(String phone, String message) async {
    if (!_storePrefs.portal().isStaff) {
      return const SmsResult(
        false,
        'Sign in through the Companion Portal as staff before sending SMS',
      );
    }
    return _smsSender.send(phone, message);
  }

  Future<void> shutdown() async {
    await stop();
    await store.close();
  }

  String _nowStamp() {
    final value = _clock();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
        '${two(value.day)} ${two(value.hour)}:${two(value.minute)}:'
        '${two(value.second)}';
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
