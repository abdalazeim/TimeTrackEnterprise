import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gateway_info.dart';

/// Discovers the desktop Attendance server through its UDP beacon.
///
/// Query: `SMARTATTENDANCE?` broadcast to UDP port 8866.
/// Reply:  `{"app":"SmartAttendanceFull","port":8080}`
class LanDiscovery {
  const LanDiscovery();

  static const int port = GatewayInfo.lanDiscoveryPort;

  Future<String?> find([
    Duration timeout = const Duration(seconds: 3),
  ]) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<String?>();
      final query = utf8.encode(GatewayInfo.lanDiscoveryQuery);

      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = socket?.receive()) != null) {
          final text = utf8.decode(
            datagram!.data,
            allowMalformed: true,
          );
          final address = _parse(text, datagram.address);
          if (address != null) {
            if (!completer.isCompleted) completer.complete(address);
            return;
          }
        }
      });

      socket.send(
        query,
        InternetAddress('255.255.255.255'),
        port,
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete(null);
      });

      return await completer.future;
    } catch (_) {
      return null;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      socket?.close();
    }
  }

  static String? _parse(String payload, InternetAddress address) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      if (decoded['app'] != 'SmartAttendanceFull') return null;
      final port = (decoded['port'] as num?)?.toInt() ?? 0;
      if (port <= 0 || port > 65535) return null;
      return 'http://${address.address}:$port';
    } catch (_) {
      return null;
    }
  }
}
