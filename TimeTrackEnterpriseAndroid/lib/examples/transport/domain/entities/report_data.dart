import 'payment_expense.dart';
import 'shipment.dart';

/// الفترات الجاهزة في شاشة التقارير.
enum ReportPeriod {
  week('آخر 7 أيام', 6),
  month('الشهر الحالي', 0),
  quarter('آخر 3 أشهر', 89),
  halfYear('آخر 6 أشهر', 179);

  const ReportPeriod(this.label, this.daysBack);

  final String label;
  final int daysBack;

  DateTime startFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (this == ReportPeriod.month) {
      return DateTime(now.year, now.month);
    }
    return today.subtract(Duration(days: daysBack));
  }
}

/// نقطة في مخطط الإيرادات.
class RevenuePoint {
  const RevenuePoint({required this.label, required this.amount});

  final String label;
  final double amount;
}

/// إجمالي عميل.
class CustomerTotal {
  const CustomerTotal({
    required this.name,
    required this.total,
    required this.shipments,
  });

  final String name;
  final double total;
  final int shipments;
}

/// ملخص التقرير المحسوب من بيانات الشحنات والتحصيل والمصروفات.
class ReportData {
  const ReportData({
    required this.start,
    required this.end,
    required this.revenue,
    required this.expenses,
    required this.net,
    required this.shipmentsCount,
    required this.completedCount,
    required this.completedFees,
    required this.openDue,
    required this.revenueByMethod,
    required this.shipmentsByStatus,
    required this.revenueTimeline,
    required this.topCustomers,
  });

  final DateTime start;
  final DateTime end;
  final double revenue;
  final double expenses;
  final double net;
  final int shipmentsCount;
  final int completedCount;
  final double completedFees;
  final double openDue;
  final Map<String, double> revenueByMethod;
  final Map<String, int> shipmentsByStatus;
  final List<RevenuePoint> revenueTimeline;
  final List<CustomerTotal> topCustomers;

  int get totalShipments => shipmentsByStatus.values.fold(0, (a, b) => a + b);

  static ReportData build({
    required List<Shipment> shipments,
    required List<Payment> payments,
    required List<Expense> expenses,
    required DateTime start,
    required DateTime end,
    List<String> methods = const <String>[],
  }) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day, 23, 59, 59);

    bool inRange(DateTime? value) =>
        value != null && !value.isBefore(from) && !value.isAfter(to);

    final periodPayments =
        payments.where((payment) => inRange(payment.date)).toList();
    final periodExpenses =
        expenses.where((expense) => inRange(expense.date)).toList();
    final periodShipments =
        shipments.where((shipment) => inRange(shipmentDate(shipment))).toList();

    final revenue = periodPayments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final expenseTotal = periodExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    final revenueByMethod = <String, double>{
      for (final method in methods) method: 0,
    };
    for (final payment in periodPayments) {
      revenueByMethod.update(
        payment.method,
        (value) => value + payment.amount,
        ifAbsent: () => payment.amount,
      );
    }

    final shipmentsByStatus = <String, int>{};
    for (final shipment in periodShipments) {
      shipmentsByStatus.update(
        shipment.status,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final completed = shipments.where(
      (shipment) => shipment.status == 'مكتملة',
    );
    final completedFees = completed.fold<double>(
      0,
      (sum, shipment) => sum + shipment.totalFee,
    );

    var openDue = 0.0;
    for (final shipment in shipments) {
      if (shipment.isDraft) continue;
      if (shipment.status == 'ملغاة' || shipment.status == 'مرتجع') continue;
      openDue += shipment.remaining;
    }

    final byCustomer = <String, CustomerTotal>{};
    for (final shipment in periodShipments) {
      final previous = byCustomer[shipment.customer];
      byCustomer[shipment.customer] = CustomerTotal(
        name: shipment.customer,
        total: (previous?.total ?? 0) + shipment.totalFee,
        shipments: (previous?.shipments ?? 0) + 1,
      );
    }
    final topCustomers = byCustomer.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return ReportData(
      start: from,
      end: to,
      revenue: revenue,
      expenses: expenseTotal,
      net: revenue - expenseTotal,
      shipmentsCount: periodShipments.length,
      completedCount: completed.length,
      completedFees: completedFees,
      openDue: openDue,
      revenueByMethod: revenueByMethod,
      shipmentsByStatus: shipmentsByStatus,
      revenueTimeline: _timeline(
        start: from,
        end: to,
        payments: periodPayments,
      ),
      topCustomers: topCustomers.take(5).toList(growable: false),
    );
  }

  /// تاريخ الشحنة التشغيلي: الاستلام ثم الإنشاء.
  static DateTime? shipmentDate(Shipment shipment) =>
      shipment.dates.receivedOrCreated;

  static List<RevenuePoint> _timeline({
    required DateTime start,
    required DateTime end,
    required List<Payment> payments,
  }) {
    final totalDays = end.difference(start).inDays + 1;
    final weekly = totalDays > 31;
    final points = <RevenuePoint>[];

    if (!weekly) {
      final byDay = <String, double>{};
      for (final payment in payments) {
        final date = payment.date;
        if (date == null) continue;
        final key = _dayKey(date);
        byDay.update(
          key,
          (value) => value + payment.amount,
          ifAbsent: () => payment.amount,
        );
      }
      for (var index = 0; index < totalDays; index++) {
        final day = start.add(Duration(days: index));
        final key = _dayKey(day);
        points.add(
          RevenuePoint(
            label: '${_two(day.month)}-${_two(day.day)}',
            amount: byDay[key] ?? 0,
          ),
        );
      }
      return points;
    }

    var cursor = start;
    while (cursor.isBefore(end)) {
      final bucketEnd = cursor.add(const Duration(days: 6));
      final last = bucketEnd.isAfter(end) ? end : bucketEnd;
      var amount = 0.0;
      for (final payment in payments) {
        final date = payment.date;
        if (date == null) continue;
        if (!date.isBefore(cursor) && !date.isAfter(last)) {
          amount += payment.amount;
        }
      }
      points.add(
        RevenuePoint(
          label: '${_two(cursor.month)}-${_two(cursor.day)}',
          amount: amount,
        ),
      );
      cursor = last.add(const Duration(days: 1));
    }
    return points;
  }

  static String _dayKey(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}
