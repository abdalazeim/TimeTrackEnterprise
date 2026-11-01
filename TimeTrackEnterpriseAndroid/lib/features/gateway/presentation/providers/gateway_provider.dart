import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_pairing.dart';
import '../../data/gateway_service.dart';
import '../../data/offline_sync.dart';
import '../../data/portal_service.dart';
import '../../data/sms_sender.dart';
import '../../domain/entities/companion_session.dart';
import '../../domain/entities/gateway_runtime.dart';
import '../../domain/entities/gateway_settings.dart';
import '../../domain/entities/offline_scan.dart';
import '../../domain/entities/portal_snapshot.dart';

/// Immutable snapshot consumed by every gateway screen.
class GatewayState {
  const GatewayState({
    required this.settings,
    required this.runtime,
    required this.companion,
    required this.portal,
    this.stats = const OfflineStats(),
    this.recent = const <QueuedScan>[],
    this.lastScan,
    this.lastGatewayCode,
    this.lastSync,
    this.lastPairing,
    this.lastScannerConnect,
    this.ip = '0.0.0.0',
    this.initialized = false,
    this.busy = false,
    this.syncing = false,
    this.portalBusy = false,
    this.message,
    this.error,
  });

  static const GatewayState initial = GatewayState(
    settings: GatewaySettings(
      port: GatewaySettings.defaultPort,
      apiKey: '',
      pairPin: '',
      deviceId: '',
      autoStart: true,
      keepAwake: true,
    ),
    runtime: GatewayRuntime(),
    companion: CompanionSession.empty,
    portal: PortalSnapshot.empty,
  );

  final GatewaySettings settings;
  final GatewayRuntime runtime;
  final CompanionSession companion;
  final PortalSnapshot portal;
  final OfflineStats stats;
  final List<QueuedScan> recent;
  final ScanVerdict? lastScan;
  final String? lastGatewayCode;
  final OfflineSyncResult? lastSync;
  final DevicePairingResult? lastPairing;
  final ScannerConnectResult? lastScannerConnect;
  final String ip;
  final bool initialized;
  final bool busy;
  final bool syncing;
  final bool portalBusy;
  final String? message;
  final String? error;

  bool get isRunning => runtime.running;

  GatewayState copyWith({
    GatewaySettings? settings,
    GatewayRuntime? runtime,
    CompanionSession? companion,
    PortalSnapshot? portal,
    OfflineStats? stats,
    List<QueuedScan>? recent,
    ScanVerdict? lastScan,
    bool clearLastScan = false,
    String? lastGatewayCode,
    OfflineSyncResult? lastSync,
    bool clearLastSync = false,
    DevicePairingResult? lastPairing,
    ScannerConnectResult? lastScannerConnect,
    String? ip,
    bool? initialized,
    bool? busy,
    bool? syncing,
    bool? portalBusy,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
  }) {
    return GatewayState(
      settings: settings ?? this.settings,
      runtime: runtime ?? this.runtime,
      companion: companion ?? this.companion,
      portal: portal ?? this.portal,
      stats: stats ?? this.stats,
      recent: recent ?? this.recent,
      lastScan: clearLastScan ? null : (lastScan ?? this.lastScan),
      lastGatewayCode: lastGatewayCode ?? this.lastGatewayCode,
      lastSync: clearLastSync ? null : (lastSync ?? this.lastSync),
      lastPairing: lastPairing ?? this.lastPairing,
      lastScannerConnect: lastScannerConnect ?? this.lastScannerConnect,
      ip: ip ?? this.ip,
      initialized: initialized ?? this.initialized,
      busy: busy ?? this.busy,
      syncing: syncing ?? this.syncing,
      portalBusy: portalBusy ?? this.portalBusy,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GatewayController extends Notifier<GatewayState> {
  late final GatewayService _service;
  bool _bootstrapped = false;

  GatewayService get service => _service;

  @override
  GatewayState build() {
    _service = GatewayService();
    ref.onDispose(() {
      unawaited(_service.shutdown());
    });
    Future<void>.microtask(_bootstrap);
    return GatewayState.initial;
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    try {
      await _service.load();
      await _refresh();
      state = state.copyWith(
        initialized: true,
        clearError: true,
        error: _service.runtime.error,
      );
    } catch (error) {
      state = state.copyWith(
        initialized: true,
        error: error.toString(),
      );
    }
  }

  Future<void> _refresh() async {
    OfflineStats stats = const OfflineStats();
    List<QueuedScan> recent = const <QueuedScan>[];
    try {
      stats = await _service.stats();
      recent = await _service.recent();
    } catch (_) {
      // The offline database may still be opening; keep the last snapshot.
      stats = state.stats;
      recent = state.recent;
    }
    state = state.copyWith(
      settings: _service.settings,
      runtime: _service.runtime,
      companion: _service.companion,
      portal: _service.portal,
      stats: stats,
      recent: recent,
      ip: _service.ip,
      initialized: _service.initialized,
    );
  }

  Future<void> refresh() => _refresh().then((_) async {
        await _service.refreshIp();
        state = state.copyWith(ip: _service.ip);
      });

  Future<void> dismissBanner() async {
    state = state.copyWith(clearMessage: true, clearError: true);
  }

  Future<void> startServer() async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      await _service.start();
      state = state.copyWith(message: 'started');
    } on GatewayException catch (error) {
      state = state.copyWith(error: error.message);
    } on Exception catch (error) {
      state = state.copyWith(error: _service.runtime.error ?? error.toString());
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<void> stopServer() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.stop();
      state = state.copyWith(message: 'stopped');
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<void> restartServer() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.restart();
      state = state.copyWith(message: 'restarted');
    } catch (error) {
      state = state.copyWith(error: _service.runtime.error ?? error.toString());
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<void> toggleAutoStart(bool value) async {
    await _service.setAutoStart(value);
    await _refresh();
  }

  Future<void> toggleKeepAwake(bool value) async {
    await _service.setKeepAwake(value);
    await _refresh();
  }

  Future<void> updateSettings(GatewaySettings settings) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.applySettings(settings);
      state = state.copyWith(message: 'settings_saved');
    } on GatewayException catch (error) {
      state = state.copyWith(error: error.code);
      rethrow;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<void> setPort(int port) =>
      updateSettings(state.settings.copyWith(port: port));

  Future<void> regenerateApiKey() async {
    try {
      await _service.regenerateApiKey();
      state = state.copyWith(message: 'key_regenerated');
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
    await _refresh();
  }

  Future<void> regeneratePairPin() async {
    try {
      await _service.regeneratePairPin();
      state = state.copyWith(message: 'pin_regenerated');
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
    await _refresh();
  }

  Future<void> updateApiKey(String value) async {
    await updateSettings(state.settings.copyWith(apiKey: value.trim()));
  }

  Future<void> updatePairPin(String value) async {
    await updateSettings(state.settings.copyWith(pairPin: value.trim()));
  }

  Future<void> setPairingEnabled(bool enabled) async {
    try {
      await _service.setPairingEnabled(enabled);
      state = state.copyWith(
        message: enabled ? 'pairing_enabled' : 'pairing_disabled',
      );
    } on GatewayException catch (error) {
      state = state.copyWith(error: error.message);
    }
    await _refresh();
  }

  void clearGatewayScans() {
    _service.clearScans();
    state = state.copyWith(
      runtime: state.runtime.copyWith(
        scansPending: 0,
        scansReceived: 0,
      ),
      clearLastScan: true,
      clearMessage: true,
      message: 'queue_cleared',
    );
  }

  int addGatewayScan(String code) {
    final seq = _service.addGatewayScan(code);
    if (seq > 0) {
      state = state.copyWith(
        lastGatewayCode: code,
        runtime: state.runtime.copyWith(
          scansPending: _service.scans.pending,
          scansReceived: _service.scans.received,
        ),
      );
    }
    return seq;
  }

  void recordGatewayScan(String code) {
    addGatewayScan(code);
  }

  Future<ScanVerdict?> scanOffline(String code) async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      final verdict = await _service.scanOffline(code);
      state = state.copyWith(lastScan: verdict);
      return verdict;
    } on GatewayException catch (error) {
      state = state.copyWith(error: error.code);
      return null;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<OfflineSyncResult?> syncOffline() async {
    state = state.copyWith(syncing: true, clearError: true, clearMessage: true);
    try {
      final result = await _service.syncOffline();
      state = state.copyWith(
        lastSync: result,
        error: result.ok ? null : _syncError(result),
        message: result.ok ? 'sync_done' : null,
      );
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(syncing: false);
      await _refresh();
    }
  }

  Future<DevicePairingResult?> refreshCompanion() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await _service.refreshCompanion();
      state = state.copyWith(lastPairing: result);
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<ScannerConnectResult?> connectScanner({
    required String server,
    required String passcode,
  }) async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      final result = await _service.connectScanner(
        server: server,
        passcode: passcode,
      );
      state = state.copyWith(
        lastScannerConnect: result,
        error: result.ok || result.pending ? null : result.message,
        message: result.ok ? 'scanner_connected' : null,
      );
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(busy: false);
      await _refresh();
    }
  }

  Future<void> disconnectScanner() async {
    await _service.disconnectScanner();
    await _refresh();
    state = state.copyWith(message: 'scanner_disconnected');
  }

  Future<void> forgetScanner() async {
    await _service.forgetScanner();
    await _refresh();
    state = state.copyWith(message: 'scanner_disconnected');
  }

  Future<String?> discoverServer() => _service.discoverServer();

  Future<bool> loginStaff({
    required String server,
    required String role,
    required String code,
  }) async {
    state =
        state.copyWith(portalBusy: true, clearError: true, clearMessage: true);
    try {
      final result = await _service.loginStaff(
        server: server,
        role: role,
        code: code,
      );
      state = state.copyWith(
        error: result.ok ? null : _portalError(result),
        message: result.ok ? 'staff_signed_in' : null,
      );
      return result.ok;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(portalBusy: false);
      await _refresh();
    }
  }

  Future<bool> loginParent({
    required String server,
    required String code,
  }) async {
    state =
        state.copyWith(portalBusy: true, clearError: true, clearMessage: true);
    try {
      final result = await _service.loginParent(server: server, code: code);
      state = state.copyWith(
        error: result.ok ? null : _portalError(result),
        message: result.ok ? 'parent_signed_in' : null,
      );
      return result.ok;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return false;
    } finally {
      state = state.copyWith(portalBusy: false);
      await _refresh();
    }
  }

  Future<void> logoutPortal() async {
    await _service.logoutPortal();
    await _refresh();
    state = state.copyWith(message: 'portal_signed_out');
  }

  Future<void> removeChild(String childId) async {
    await _service.removeChild(childId);
    await _refresh();
  }

  Future<PortalDataResult?> staffDashboard() async {
    state = state.copyWith(portalBusy: true, clearError: true);
    try {
      final result = await _service.staffDashboard();
      if (!result.ok) {
        state = state.copyWith(error: _portalDataError(result));
      }
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(portalBusy: false);
    }
  }

  Future<PortalDataResult?> parentData(PortalChild child) async {
    state = state.copyWith(portalBusy: true, clearError: true);
    try {
      final result = await _service.parentData(child);
      if (!result.ok) {
        state = state.copyWith(error: _portalDataError(result));
      }
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    } finally {
      state = state.copyWith(portalBusy: false);
    }
  }

  Future<PortalDataResult?> parentNotifications(PortalChild child) async {
    try {
      final result = await _service.parentNotifications(child);
      if (!result.ok) {
        state = state.copyWith(error: _portalDataError(result));
      }
      return result;
    } catch (error) {
      state = state.copyWith(error: error.toString());
      return null;
    }
  }

  Future<PortalDataResult?> markNotificationsRead(
    PortalChild child,
    List<int> ids,
  ) async {
    final result = await _service.markNotificationsRead(child, ids);
    await _refresh();
    return result;
  }

  Future<SmsResult> sendSms(String phone, String message) async {
    state = state.copyWith(clearError: true, clearMessage: true);
    final result = await _service.sendSms(phone, message);
    state = state.copyWith(
      message: result.ok ? 'sms_queued' : null,
      error: result.ok ? null : result.detail,
    );
    return result;
  }

  static String? _syncError(OfflineSyncResult result) {
    if (result.devicePending) return 'device_pending';
    if (result.deviceBlocked) return 'device_blocked';
    if (result.deviceUnknown) return 'device_unknown';
    if (result.unauthorized) return 'session_expired';
    if (result.noSession) return 'staff_required';
    if (result.offline) return 'offline';
    return result.message.isEmpty ? 'sync_failed' : result.message;
  }

  static String _portalError(PortalLoginResult result) =>
      result.code.isEmpty ? result.message : result.code;

  static String _portalDataError(PortalDataResult result) =>
      result.code.isEmpty ? result.message : result.code;
}

final gatewayProvider =
    NotifierProvider<GatewayController, GatewayState>(GatewayController.new);
