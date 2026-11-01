import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/failure_mapper.dart';

/// تنسيقات عربية موحّدة للأرقام والتواريخ.
String formatMoney(num value) {
  final number = value.toDouble();
  final absolute = number.abs();
  final hasFraction = (absolute - absolute.roundToDouble()).abs() > 0.004;
  final text =
      hasFraction ? absolute.toStringAsFixed(2) : absolute.round().toString();
  final parts = text.split('.');
  final grouped = _group(parts.first);
  final sign = number < 0 ? '-' : '';
  final fraction = parts.length > 1 ? '.${parts[1]}' : '';
  return '$signد.ل $grouped$fraction';
}

String formatNumber(num value, {int decimals = 0}) {
  final fixed = value.toDouble().toStringAsFixed(decimals);
  final negative = fixed.startsWith('-');
  final parts = (negative ? fixed.substring(1) : fixed).split('.');
  final grouped = _group(parts.first);
  final fraction = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}$grouped$fraction';
}

String formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.year}/${_two(local.month)}/${_two(local.day)}';
}

String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${formatDate(local)} ${_two(local.hour)}:${_two(local.minute)}';
}

String formatShortDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${_two(local.month)}-${_two(local.day)}';
}

String formatPlan(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}'
    'T${_two(value.hour)}:${_two(value.minute)}';

String errorMessage(Object error) {
  if (error is ApiException) return error.failure.message;
  return '$error';
}

/// يفك صورة data URL القادمة من إثبات التسليم.
Uint8List? decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _group(String digits) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

/// لون دلالي موحّد لحالات الشحنات والرحلات.
Color statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'مكتملة':
    case 'تم التسليم':
    case 'وصلت للوجهة':
    case 'مدفوع':
      return const Color(0xFF17795E);
    case 'تم الشحن':
    case 'قيد النقل':
    case 'في الطريق':
    case 'تم التحميل':
    case 'جاهزة للشحن':
      return const Color(0xFF1E5FA8);
    case 'جاهزة للتسليم':
    case 'جزئي':
    case 'مؤجلة':
      return const Color(0xFFB3741A);
    case 'ملغاة':
    case 'فشل التسليم':
      return scheme.error;
    case 'مرتجع':
    case 'معلقة':
    case 'مسودة':
    case 'مخططة':
      return const Color(0xFF6B7280);
    default:
      return const Color(0xFF3F5F8F);
  }
}
