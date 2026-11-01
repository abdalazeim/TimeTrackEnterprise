import 'dart:async';
import 'dart:io';

import '../domain/entities/offline_scan.dart';
import 'device_pairing.dart';
import 'gateway_info.dart';
import 'gateway_mobile_api.dart';
import 'gateway_rules.dart';
import 'local/gateway_prefs.dart';
import 'local/offline_store.dart';

/// Outcome of an offline roster/scan synchronisation pass.
class OfflineSyncResult {
  const OfflineSyncResult({
    this.ok = false,
    this.noSession = false,
    this.devicePending = false,
    this.deviceBlocked = false,
    this.deviceUnknown = false,
    this.offline = false,
    this.unauthorized = false,
    this.rosterChanged = false,
    this.sent = 0,
    this.already = 0,
    this.rejected = 0,
    this.message = '',
  });

  final bool ok;
  final bool noSession;
  final bool devicePending;
  final bool deviceBlocked;
  final bool deviceUnknown;
  final bool offline;
  final bool unauthorized;
  final bool rosterChanged;
  final int sent;
  final int already;
  final int rejected;
  final String message;
}

/// Synchronises the local roster and queued scans with the web backend.
class OfflineSync {
  OfflineSync({
    required GatewayPrefs prefs,
    required OfflineStore store,
    DevicePairing? pairing,
    String? deviceName,
    MobileApi Function(String baseUrl, String token)? apiFactory,
  })  : _prefs = prefs,
        _store = store,
        _pairing = pairing ??
            DevicePairing(prefs: prefs, deviceName: deviceName),
        _deviceName = deviceName ?? deviceDisplayName(),
        _apiFactory = apiFactory ??
            ((baseUrl, token) => MobileApi(
                  baseUrl: baseUrl,
                  token: token,
                  version: GatewayInfo.version,
                ));

  static const int batchSize = 300;

  final GatewayPrefs _prefs;
  final OfflineStore _store;
  final DevicePairing _pairing;
  final String _deviceName;
  final MobileApi Function(String baseUrl, String token) _apiFactory;

  Future<OfflineSyncResult> run() async {
    final portal = _prefs.portal();
    if (!portal.isStaff) {
      return const OfflineSyncResult(noSession: true);
    }

    final companion = _prefs.companion();
    final base = PortalRules.normalizeServer(companion.serverUrl);
    if (base == null) {
      return const OfflineSyncResult(noSession: true);
    }

    if (companion.deviceSecret.isNotEmpty) {
      final refresh = await _pairing.refresh();
      if (refresh.pending) {
        return const OfflineSyncResult(devicePending: true);
      }
      if (refresh.blocked) {
        return const OfflineSyncResult(deviceBlocked: true);
      }
      if (refresh.unknown) {
        return OfflineSyncResult(
          deviceUnknown: true,
          message: refresh.message,
        );
      }
      if (refresh.offline) {
        return const OfflineSyncResult(offline: true);
      }
    }

    final session = _prefs.companion();
    if (!session.hasSession) {
      return const OfflineSyncResult(noSession: true);
    }

    final api = _apiFactory(base, session.token);
    try {
      final version = await _store.rosterVersion();
      final roster = await api.get(
        '/api/mobile/offline/roster',
        <String, String>{
          'device_id': _prefs.deviceId,
          if (version.isNotEmpty) 'since': version,
        },
      );
      final rosterChanged = await _store.applyRoster(roster);

      var sent = 0;
      var already = 0;
      var rejected = 0;

      while (true) {
        final pending = await _store.pending(batchSize);
        if (pending.isEmpty) break;

        final response = await api.post(
          '/api/mobile/scans/sync',
          _buildBatch(pending),
        );
        final summary = response['summary'];
        if (summary is Map) {
          sent += (summary['processed'] as num?)?.toInt() ?? 0;
          already += (summary['duplicates'] as num?)?.toInt() ?? 0;
          rejected += (summary['rejected'] as num?)?.toInt() ?? 0;
        }
        await _store.applySyncResults(response);

        if (pending.length < batchSize) break;
      }

      if (session.deviceSecret.isNotEmpty) {
        await _prefs.setCompanionStatus('approved', pairCode: '');
      }

      return OfflineSyncResult(
        ok: true,
        rosterChanged: rosterChanged,
        sent: sent,
        already: already,
        rejected: rejected,
      );
    } on MobileApiException catch (error) {
      final code = error.code;
      if (code == 'device_pending') {
        return OfflineSyncResult(
          devicePending: true,
          message: error.message,
        );
      }
      if (code == 'device_blocked') {
        await _prefs.setCompanionStatus('blocked', pairCode: '');
        return OfflineSyncResult(
          deviceBlocked: true,
          message: error.message,
        );
      }
      if (code == 'device_unknown' ||
          code == 'device_required' ||
          code == 'invalid_device') {
        return OfflineSyncResult(
          deviceUnknown: true,
          message: error.message,
        );
      }
      if (error.status == 401) {
        final current = _prefs.companion();
        await _prefs.saveCompanion(
          current.copyWith(token: ''),
        );
        return OfflineSyncResult(
          unauthorized: true,
          message: error.message,
        );
      }
      return OfflineSyncResult(message: error.message);
    } on SocketException {
      return const OfflineSyncResult(offline: true);
    } on TimeoutException {
      return const OfflineSyncResult(offline: true);
    } on IOException {
      return const OfflineSyncResult(offline: true);
    } catch (error) {
      return OfflineSyncResult(message: error.toString());
    } finally {
      api.close();
    }
  }

  Map<String, Object?> _buildBatch(List<QueuedScan> scans) {
    return <String, Object?>{
      'device_id': _prefs.deviceId,
      'device_name': _deviceName,
      'platform': 'android',
      'app_version': GatewayInfo.version,
      'scans': scans
          .map(
            (scan) => <String, Object?>{
              'client_id': scan.clientId,
              'code': scan.code,
              'at': scan.scannedAt,
            },
          )
          .toList(growable: false),
    };
  }
}
