import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gateway_rules.dart';

/// HTTP error returned by the web backend.
class MobileApiException implements Exception {
  const MobileApiException(
    this.status,
    this.code,
    this.message, {
    this.body,
  });

  final int status;
  final String code;
  final String message;
  final Map<String, Object?>? body;

  @override
  String toString() => message.isEmpty ? code : message;
}

/// Minimal mobile API client matching `MobileApi.java`.
///
/// * only `/api/mobile/` paths are allowed,
/// * redirects are rejected,
/// * the same identification headers are sent,
/// * connect timeout is 12 s and response timeout is 64 s.
class MobileApi {
  MobileApi({
    required this.baseUrl,
    this.token = '',
    this.version = '4.1.1',
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  static const String defaultVersion = '4.1.1';
  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 64);
  static const int maxResponseBytes = 4 * 1024 * 1024;

  final String baseUrl;
  final String token;
  final String version;
  final HttpClient _client;

  Future<Map<String, Object?>> get(
    String path, [
    Map<String, String>? query,
  ]) {
    return _request('GET', path, query, null);
  }

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) {
    return _request('POST', path, null, body);
  }

  Future<Map<String, Object?>> _request(
    String method,
    String path,
    Map<String, String>? query,
    Map<String, Object?>? body,
  ) async {
    final base = PortalRules.normalizeServer(baseUrl);
    if (base == null ||
        !path.startsWith('/api/mobile/') ||
        path.contains('..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const MobileApiException(
        0,
        'invalid_destination',
        'Invalid API destination',
      );
    }

    final queryString = _buildQuery(query);
    final uri = Uri.parse(
      '$base$path${queryString.isEmpty ? '' : '?$queryString'}',
    );

    final client = _client
      ..connectionTimeout = connectTimeout
      ..findProxy = ((_) => 'DIRECT')
      ..badCertificateCallback = ((cert, host, port) => false);

    try {
      final request = await client.openUrl(method, uri).timeout(connectTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Requested-With', 'StudentAttendance');
      request.headers.set('User-Agent', 'SmartAttendanceGateway/$version');
      if (token.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $token',
        );
      }

      if (body != null) {
        final bytes = utf8.encode(jsonEncode(body));
        request.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close().timeout(receiveTimeout);
      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        await response.drain<void>();
        throw const MobileApiException(
          0,
          'redirect_rejected',
          'The server redirected the request',
        );
      }

      final text = await _readText(response).timeout(receiveTimeout);

      Map<String, Object?> json;
      try {
        json = text.isEmpty
            ? <String, Object?>{}
            : (jsonDecode(text) as Map).cast<String, Object?>();
      } catch (_) {
        if (status < 200 || status >= 300) {
          throw MobileApiException(
            status,
            'http_$status',
            _defaultMessage(status),
          );
        }
        throw const MobileApiException(
          0,
          'invalid_response',
          'The server returned an invalid response',
        );
      }

      final ok = json['ok'] != false;
      if (status >= 200 && status < 300 && ok && !json.containsKey('error')) {
        return json;
      }

      final error = json['error'];
      String? code;
      String? message;
      if (error is Map) {
        final map = error.cast<String, Object?>();
        code = map['code']?.toString();
        message = map['message']?.toString();
      } else if (error is String && error.isNotEmpty) {
        message = error;
      }
      return _throwError(
        status,
        code ?? 'http_$status',
        message ?? _defaultMessage(status),
        json,
      );
    } on SocketException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on HttpException {
      rethrow;
    }
  }

  static Never _throwError(
    int status,
    String code,
    String message,
    Map<String, Object?> body,
  ) {
    throw MobileApiException(status, code, message, body: body);
  }

  static String _buildQuery(Map<String, String>? query) {
    if (query == null || query.isEmpty) return '';
    final parts = <String>[];
    query.forEach((key, value) {
      if (value.isEmpty) return;
      parts.add(
        '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}',
      );
    });
    return parts.join('&');
  }

  static Future<String> _readText(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > maxResponseBytes) {
        throw const MobileApiException(
          0,
          'response_too_large',
          'The server response is too large',
        );
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _defaultMessage(int status) {
    switch (status) {
      case 401:
        return 'The session has ended. Sign in again.';
      case 402:
        return 'A subscription is required. Contact the administration.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested service was not found.';
      case 429:
        return 'Too many attempts. Try again shortly.';
      default:
        return 'The server returned an error ($status).';
    }
  }

  void close() => _client.close(force: true);

  /// Builds a client for a normalised base URL.
  static MobileApi forBase(String baseUrl, {String token = ''}) =>
      MobileApi(baseUrl: baseUrl, token: token);
}
