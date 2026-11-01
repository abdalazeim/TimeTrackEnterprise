import 'value_readers.dart';

/// سند قبض من `/payments/`. نحتاجه للتقارير فقط.
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.method,
    this.shipmentId,
    this.agent,
    this.date,
  });

  final String id;
  final double amount;
  final String method;
  final String? shipmentId;
  final String? agent;
  final DateTime? date;

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: readText(json['id']),
      amount: readNumber(json['amount']),
      method: readText(json['method'], fallback: 'غير محدد'),
      shipmentId: readTextOrNull(json['shipId']),
      agent: readTextOrNull(json['agent']),
      date: readDate(json['created']) ??
          readDate(json['date']) ??
          readDate(json['time']),
    );
  }
}

/// مصروف من `/expenses/`.
class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.tripId,
    this.date,
  });

  final String id;
  final double amount;
  final String category;
  final String? tripId;
  final DateTime? date;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: readText(json['id']),
      amount: readNumber(json['amount']),
      category: readText(json['cat'], fallback: 'عام'),
      tripId: readTextOrNull(json['tripId']),
      date: readDate(json['created']) ?? readDate(json['date']),
    );
  }
}
