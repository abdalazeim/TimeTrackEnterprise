import '../error/failure.dart';
import 'failure_mapper.dart';

/// قراءة المغلف القياسي للـAPI مع دعم الاستثناءات الموثقة.
class Envelope {
  const Envelope._();

  static void ensureSuccess(Object? body) {
    if (body is Map && body['success'] == false) {
      throw ApiException(
        FailureMapper.fromEnvelope(body.cast<String, dynamic>()),
      );
    }
  }

  static Map<String, dynamic> asMap(Object? body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return body.cast<String, dynamic>();
    throw const ApiException(ParseFailure('استجابة الخادم ليست كائن JSON.'));
  }

  /// يعيد `data` إن وُجد، وإلا الكائن نفسه (لبعض المسارات التي تعيد الكيان مباشرة).
  static Map<String, dynamic> dataMap(Object? body) {
    final map = asMap(body);
    if (map['success'] == false) {
      throw ApiException(FailureMapper.fromEnvelope(map));
    }
    final data = map['data'];
    if (data is Map) return data.cast<String, dynamic>();
    if (data == null) return map;
    throw const ApiException(ParseFailure('حقل data ليس كائنًا.'));
  }

  static List<dynamic> dataList(Object? body) {
    final map = asMap(body);
    if (map['success'] == false) {
      throw ApiException(FailureMapper.fromEnvelope(map));
    }
    final data = map['data'];
    if (data is List) return data;
    if (data is Map) {
      final items = data['items'];
      if (items is List) return items;
    }
    throw const ApiException(ParseFailure('حقل data ليس قائمة.'));
  }

  static String? messageOf(Object? body) {
    if (body is! Map) return null;
    final value = body['message'] ?? body['error'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
