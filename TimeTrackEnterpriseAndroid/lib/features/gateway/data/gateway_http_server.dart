import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../domain/entities/scan_event.dart';
import 'gateway_info.dart';
import 'local/scan_queue.dart';
import 'sms_sender.dart';

typedef SmsHandler = Future<SmsResult> Function(String phone, String message);

class _HttpError implements Exception {
  const _HttpError(this.status, this.message, {this.extra});

  final int status;
  final String message;
  final Map<String, Object?>? extra;
}

/// Local HTTP SMS + scans gateway, compatible with the desktop Attendance app.
///
/// Endpoints:
/// * `GET /` and `GET /health` — status (no auth)
/// * `GET /scans?after=<seq>` — pending scans (`X-Api-Key`)
/// * `POST /pair` — exchange the 4 digit PIN for the API key
/// * `POST /send` — send an SMS (`X-Api-Key`)
class GatewayHttpServer {
  GatewayHttpServer({
    required this.port,
    required this.apiKey,
    required this.pairPin,
    required this.scans,
    SmsHandler? smsHandler,
    void Function(String? userAgent)? onPcSeen,
    DateTime Function()? clock,
  })  : _smsHandler = smsHandler,
        _onPcSeen = onPcSeen,
        _clock = clock ?? DateTime.now;

  static const int maxBodyBytes = 65536;
  static const int maxHeadBytes = 16384;
  static const int maxScansPerResponse = 20;
  static const int pairMaxAttempts = 5;
  static const Duration pairWindow = Duration(seconds: 60);
  static const Duration socketTimeout = Duration(seconds: 15);

  final int port;
  final String apiKey;
  final String pairPin;
  final ScanQueue scans;

  final SmsHandler? _smsHandler;
  final void Function(String? userAgent)? _onPcSeen;
  final DateTime Function() _clock;

  HttpServer? _server;
  bool _running = false;

  int _pairFailures = 0;
  DateTime? _pairWindowStart;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    server.idleTimeout = socketTimeout;
    _server = server;
    _running = true;
    server.listen(
      _handle,
      onError: (Object error) {
        if (_running) {
          // Ignore individual socket errors; the server keeps serving.
        }
      },
    );
  }

  Future<void> stop() async {
    _running = false;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final userAgent = request.headers.value(HttpHeaders.userAgentHeader);
    final clientApp = request.headers.value('x-client-app');
    if ((clientApp != null && clientApp.toLowerCase() == 'smartattendance') ||
        (userAgent != null && userAgent.startsWith('SmartAttendance/'))) {
      _onPcSeen?.call(userAgent);
    }

    try {
      await _route(request);
    } on _HttpError catch (error) {
      await _respondJson(
        request.response,
        error.status,
        <String, Object?>{..._error(error.message), ...?error.extra},
      );
    } catch (_) {
      await _respondJson(
        request.response,
        500,
        _error('Request failed'),
      );
    }
  }

  Future<void> _route(HttpRequest request) async {
    final method = request.method.toUpperCase();
    final path = request.uri.path;

    if (method == 'OPTIONS') {
      await _respondEmpty(request.response);
      return;
    }

    if (method == 'GET' && (path == '/' || path == '/health')) {
      await _respondJson(request.response, 200, _status());
      return;
    }

    if (path == GatewayInfo.scansPath || path == '${GatewayInfo.scansPath}/') {
      if (method != 'GET') {
        throw const _HttpError(405, 'Use GET for this endpoint');
      }
      if (!_authorized(request)) {
        throw const _HttpError(401, 'Invalid or missing API key');
      }
      await _respondJson(request.response, 200, _scanResponse(request.uri));
      return;
    }

    if (path == '/pair' || path == '/pair/') {
      if (method != 'POST') {
        throw const _HttpError(405, 'Use POST for this endpoint');
      }
      await _respondJson(request.response, 200, await _pairResponse(request));
      return;
    }

    if (method == 'POST' && _isSendPath(path)) {
      if (!_authorized(request)) {
        throw const _HttpError(401, 'Invalid or missing API key');
      }
      final body = await _readJsonBody(request);
      final phone = normalizePhone(
        _string(body['phone'] ?? body['to']),
      );
      if (phone == null) {
        throw const _HttpError(400, 'Invalid phone number');
      }
      final message = _string(body['message'] ?? body['text']) ?? '';
      if (message.trim().isEmpty) {
        throw const _HttpError(400, 'Message is empty');
      }
      if (message.length > 2000) {
        throw const _HttpError(
          413,
          'Message is longer than 2000 characters',
        );
      }

      final handler = _smsHandler;
      final result = handler == null
          ? const SmsResult(false, 'SMS service is unavailable on this device')
          : await handler(phone, message);
      if (result.ok) {
        await _respondJson(
          request.response,
          200,
          <String, Object?>{'ok': true, 'detail': result.detail},
        );
      } else {
        throw _HttpError(500, result.detail);
      }
      return;
    }

    if (_isSendPath(path)) {
      throw const _HttpError(405, 'Use POST for this endpoint');
    }

    throw const _HttpError(404, 'Not found');
  }

  bool _isSendPath(String path) =>
      path == GatewayInfo.sendPath ||
      path == '${GatewayInfo.sendPath}/' ||
      path == '/api/send' ||
      path == '/api/send/' ||
      path == '/';

  bool _authorized(HttpRequest request) {
    if (apiKey.isEmpty) return true;
    final provided = request.headers.value('x-api-key');
    if (provided == null) return false;
    return _constantTimeEquals(apiKey, provided.trim());
  }

  Map<String, Object?> _status() => <String, Object?>{
        'ok': true,
        'app': GatewayInfo.gatewayName,
        'version': GatewayInfo.version,
        'status': _running ? 'running' : 'stopped',
        'port': port,
        'authRequired': apiKey.isNotEmpty,
        'pairing': true,
        'scanner': true,
        'scansPending': scans.pending,
      };

  Map<String, Object?> _scanResponse(Uri uri) {
    final resync = uri.queryParameters['resync'];
    final after = int.tryParse(uri.queryParameters['after'] ?? '') ?? 0;
    final resyncAll = resync == '1' || (resync?.toLowerCase() == 'true');
    final List<ScanEvent> events =
        resyncAll ? const <ScanEvent>[] : scans.since(after < 0 ? 0 : after);
    final limited = events
        .take(maxScansPerResponse)
        .map(
          (event) => <String, Object?>{
            'seq': event.seq,
            'code': event.code,
            'at': event.at.millisecondsSinceEpoch,
          },
        )
        .toList(growable: false);
    return <String, Object?>{
      'ok': true,
      'version': GatewayInfo.version,
      'lastSeq': scans.lastSeq,
      'scans': limited,
    };
  }

  Future<Map<String, Object?>> _pairResponse(HttpRequest request) async {
    final body = await _readJsonBody(request);
    if (pairPin.isEmpty) {
      throw const _HttpError(503, 'Pairing is disabled');
    }

    final remaining = _pairBlockRemaining();
    if (remaining > Duration.zero) {
      final seconds = remaining.inSeconds < 1 ? 1 : remaining.inSeconds;
      throw _HttpError(
        429,
        'Too many pairing attempts. Try again shortly.',
        extra: <String, Object?>{'retryAfter': seconds},
      );
    }

    final pin = (_string(body['pin']) ?? '').trim();
    if (!_isFourDigits(pin) || !_constantTimeEquals(pairPin, pin)) {
      _recordPairFailure();
      throw const _HttpError(401, 'Invalid pairing code');
    }

    _recordPairSuccess();
    return <String, Object?>{
      'ok': true,
      'app': GatewayInfo.gatewayName,
      'version': GatewayInfo.version,
      'port': port,
      'apiKey': apiKey,
      'authRequired': apiKey.isNotEmpty,
      'pairing': true,
    };
  }

  Duration _pairBlockRemaining() {
    if (_pairFailures < pairMaxAttempts) return Duration.zero;
    final start = _pairWindowStart;
    if (start == null) return Duration.zero;
    final elapsed = _clock().difference(start);
    if (elapsed >= pairWindow) {
      _pairFailures = 0;
      return Duration.zero;
    }
    return pairWindow - elapsed;
  }

  void _recordPairFailure() {
    final now = _clock();
    final start = _pairWindowStart;
    if (_pairFailures == 0 ||
        start == null ||
        now.difference(start) >= pairWindow) {
      _pairWindowStart = now;
      _pairFailures = 0;
    }
    _pairFailures += 1;
  }

  void _recordPairSuccess() {
    _pairFailures = 0;
    _pairWindowStart = null;
  }

  Future<Map<String, Object?>> _readJsonBody(HttpRequest request) async {
    final rawLength = request.headers.value(HttpHeaders.contentLengthHeader);
    if (rawLength == null || rawLength.isEmpty) {
      throw const _HttpError(400, 'JSON body is required');
    }
    final length = int.tryParse(rawLength);
    if (length == null) {
      throw const _HttpError(400, 'Invalid Content-Length');
    }
    if (length < 0 || length > maxBodyBytes) {
      throw const _HttpError(413, 'Request body is too large');
    }
    if (length == 0) {
      throw const _HttpError(400, 'JSON body is required');
    }

    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > maxBodyBytes) {
        throw const _HttpError(413, 'Request body is too large');
      }
    }
    if (bytes.length != length) {
      throw const _HttpError(400, 'Invalid JSON body');
    }

    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Expected an object');
      }
      return decoded.cast<String, Object?>();
    } catch (_) {
      throw const _HttpError(400, 'Invalid JSON body');
    }
  }

  Future<void> _respondJson(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    if (response.headers.contentType == null) {
      _applyCors(response);
    }
    response
      ..statusCode = status
      ..headers.contentType =
          ContentType('application', 'json', charset: 'utf-8')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('X-Content-Type-Options', 'nosniff')
      ..persistentConnection = false;
    _applyCors(response);
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _respondEmpty(HttpResponse response) async {
    response
      ..statusCode = 204
      ..persistentConnection = false;
    _applyCors(response);
    await response.close();
  }

  static void _applyCors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, X-Api-Key',
    );
    response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
  }

  static Map<String, Object?> _error(String message) => <String, Object?>{
        'ok': false,
        'error': message,
      };

  static String? _string(Object? value) {
    if (value == null) return null;
    return value.toString();
  }

  static String? normalizePhone(String? input) {
    if (input == null) return null;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      var unit = rune;
      if (unit >= 0x0660 && unit <= 0x0669) {
        unit -= 1584;
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        unit -= 1728;
      }
      if (unit >= 0x30 && unit <= 0x39) {
        buffer.writeCharCode(unit);
      } else if (unit == 0x2B && buffer.isEmpty) {
        buffer.write('+');
      }
    }
    var result = buffer.toString();
    if (result.startsWith('00')) {
      result = '+${result.substring(2)}';
    }
    final digits = result.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6 || digits.length > 15) return null;
    return result;
  }

  static bool _isFourDigits(String value) => RegExp(r'^\d{4}$').hasMatch(value);

  static bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    final length = min(a.length, b.length);
    for (var index = 0; index < length; index++) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }
}
