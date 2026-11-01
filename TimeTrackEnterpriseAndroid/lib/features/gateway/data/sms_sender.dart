import 'dart:io';

import 'package:flutter/services.dart';

/// Result of an SMS hand-off to the Android telephony stack.
class SmsResult {
  const SmsResult(this.ok, this.detail);

  final bool ok;
  final String detail;

  static const SmsResult unavailable =
      SmsResult(false, 'SMS service is unavailable on this device');
}

/// Sends SMS through the Android MethodChannel implemented in `MainActivity`.
///
/// The local gateway remains usable on desktop; sending simply reports that
/// the SMS service is unavailable, while scans and the HTTP status endpoint
/// keep working.
class SmsSender {
  SmsSender({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'attendance_gateway/sms';

  final MethodChannel _channel;

  Future<SmsResult> send(String phone, String message) async {
    if (!Platform.isAndroid) return SmsResult.unavailable;
    final trimmedPhone = phone.trim();
    if (trimmedPhone.isEmpty) {
      return const SmsResult(false, 'Phone number is empty');
    }
    if (message.trim().isEmpty) {
      return const SmsResult(false, 'Message is empty');
    }
    if (message.length > 2000) {
      return const SmsResult(
        false,
        'Message is longer than 2000 characters',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'sendSms',
        <String, Object?>{'phone': trimmedPhone, 'message': message},
      );
      final ok = result?['ok'] == true;
      final detail = result?['detail']?.toString() ?? '';
      return SmsResult(ok, detail.isEmpty ? (ok ? 'queued' : 'SMS failed') : detail);
    } on MissingPluginException {
      return SmsResult.unavailable;
    } on PlatformException catch (error) {
      return SmsResult(
        false,
        error.message?.isNotEmpty == true ? error.message! : error.code,
      );
    } catch (error) {
      return SmsResult(false, error.toString());
    }
  }
}
