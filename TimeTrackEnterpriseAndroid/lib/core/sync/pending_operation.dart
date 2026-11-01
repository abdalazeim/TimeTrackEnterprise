import 'dart:convert';

/// حالات عملية الطابور.
enum OperationStatus {
  /// في الانتظار للإرسال.
  pending,

  /// أُرسلت ولم يصل تأكيد (قد تكون طُبّقت على الخادم).
  sent,

  /// فشل عابر (شبكة/5xx/429) وستُعاد المحاولة.
  failed,

  /// رفض دائم (400/403/422) — تحتاج تدخل المستخدم.
  rejected,

  /// نجحت على الخادم.
  applied,

  /// تجاوزت سقف المحاولات.
  dead;

  static OperationStatus parse(String raw) {
    for (final status in OperationStatus.values) {
      if (status.name == raw) return status;
    }
    return OperationStatus.pending;
  }

  bool get isTerminal =>
      this == OperationStatus.applied ||
      this == OperationStatus.rejected ||
      this == OperationStatus.dead;

  bool get needsAttention =>
      this == OperationStatus.rejected || this == OperationStatus.dead;
}

/// عملية محلية جاهزة للدفع — `operation_id` ثابت يمنع تكرار الأثر.
class PendingOperation {
  const PendingOperation({
    required this.operationId,
    required this.kind,
    required this.payload,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
    this.entityType,
    this.entityId,
    this.nextAttemptAt,
    this.lastError,
    this.lastStatusCode,
  });

  final String operationId;
  final String kind;
  final String? entityType;
  final String? entityId;
  final Map<String, dynamic> payload;
  final OperationStatus status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final int? lastStatusCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// الشكل الذي يرسله الخادم في `operations`.
  Map<String, dynamic> toPushJson() => <String, dynamic>{
        'operation_id': operationId,
        'kind': kind,
        'payload': payload,
      };

  /// الشكل الذي يُرسل إلى الواجهة (بلا أي محتوى حساس).
  Map<String, dynamic> toSummaryJson() => <String, dynamic>{
        'operation_id': operationId,
        'kind': kind,
        'entity_type': entityType,
        'entity_id': entityId,
        'status': status.name,
        'attempts': attempts,
      };

  factory PendingOperation.fromRow(Map<String, Object?> row) {
    final payloadRaw = row['payload'] as String? ?? '{}';
    final decoded = jsonDecode(payloadRaw);
    return PendingOperation(
      operationId: row['operation_id']! as String,
      kind: row['kind']! as String,
      entityType: row['entity_type'] as String?,
      entityId: row['entity_id'] as String?,
      payload: decoded is Map
          ? decoded.cast<String, dynamic>()
          : const <String, dynamic>{},
      status: OperationStatus.parse(row['status'] as String? ?? 'pending'),
      attempts: (row['attempts'] as int?) ?? 0,
      nextAttemptAt: _parseDate(row['next_attempt_at']),
      lastError: row['last_error'] as String?,
      lastStatusCode: row['last_status_code'] as int?,
      createdAt: _parseDate(row['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _parseDate(row['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
