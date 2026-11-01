/// قراءة متسامحة لقيم JSON لأن الخادم يخلط النصوص والأرقام.
library;

String readText(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value.trim();
  return '$value'.trim();
}

String? readTextOrNull(Object? value) {
  final text = readText(value);
  return text.isEmpty ? null : text;
}

double readNumber(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final text = readText(value).replaceAll(',', '');
  return double.tryParse(text) ?? 0;
}

int readInteger(Object? value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(readText(value)) ?? 0;
}

bool readFlag(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = readText(value).toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'نعم';
}

Map<String, dynamic> readObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<dynamic> readArray(Object? value) {
  if (value is List) return value;
  return const <dynamic>[];
}

DateTime? readDate(Object? value) {
  final text = readText(value);
  if (text.isEmpty) return null;
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

/// يحوّل نصًا يحتوي أرقامًا عربية إلى رقم عادي.
double? parseInputNumber(String raw) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
  var text = raw.trim().replaceAll(',', '').replaceAll('٬', '');
  for (var i = 0; i < 10; i++) {
    text = text
        .replaceAll(arabicIndic[i], '$i')
        .replaceAll(easternArabic[i], '$i');
  }
  return double.tryParse(text);
}
