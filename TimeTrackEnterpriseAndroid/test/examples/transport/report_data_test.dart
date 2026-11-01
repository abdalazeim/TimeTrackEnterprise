import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/examples/transport/domain/entities/payment_expense.dart';
import 'package:generic_template/examples/transport/domain/entities/report_data.dart';
import 'package:generic_template/examples/transport/domain/entities/shipment.dart';

Shipment shipment({
  required String id,
  required String status,
  required String customer,
  required double total,
  required double paid,
  required double due,
  String created = '2026-09-05 10:00:00',
  bool isDraft = false,
}) {
  return Shipment.fromJson(<String, dynamic>{
    'id': id,
    'customer': customer,
    'status': status,
    'draft': isDraft ? 1 : 0,
    'fee': <String, dynamic>{'total': total},
    'feeTotal': total,
    'paid': paid,
    'due': due,
    'dates': <String, dynamic>{'rec': created, 'draft': created},
  });
}

Payment payment({
  required String id,
  required double amount,
  required String method,
  required String created,
}) {
  return Payment.fromJson(<String, dynamic>{
    'id': id,
    'amount': amount,
    'method': method,
    'created': created,
  });
}

Expense expense({
  required String id,
  required double amount,
  required String created,
}) {
  return Expense.fromJson(<String, dynamic>{
    'id': id,
    'amount': amount,
    'cat': 'وقود',
    'created': created,
  });
}

void main() {
  group('ReportPeriod', () {
    final now = DateTime(2026, 10, 20, 15, 30);

    test('month starts at the first day of the month', () {
      expect(ReportPeriod.month.startFrom(now), DateTime(2026, 10, 1));
    });

    test('week includes today and the previous six days', () {
      expect(ReportPeriod.week.startFrom(now), DateTime(2026, 10, 14));
    });

    test('quarter and half year use fixed windows', () {
      expect(ReportPeriod.quarter.startFrom(now), DateTime(2026, 7, 23));
      expect(ReportPeriod.halfYear.startFrom(now), DateTime(2026, 4, 24));
    });

    test('all periods have Arabic labels', () {
      for (final period in ReportPeriod.values) {
        expect(period.label, isNotEmpty);
      }
    });
  });

  group('ReportData.build', () {
    late ReportData report;

    setUp(() {
      report = ReportData.build(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 10),
        methods: const <String>['كاش', 'بنك', 'آجل'],
        shipments: <Shipment>[
          shipment(
            id: 'S1',
            status: 'مكتملة',
            customer: 'عميل أ',
            total: 500,
            paid: 200,
            due: 300,
          ),
          shipment(
            id: 'S2',
            status: 'قيد النقل',
            customer: 'عميل ب',
            total: 200,
            paid: 100,
            due: 100,
          ),
          shipment(
            id: 'S3',
            status: 'مسودة',
            customer: 'عميل أ',
            total: 80,
            paid: 0,
            due: 80,
            isDraft: true,
          ),
          shipment(
            id: 'S4',
            status: 'ملغاة',
            customer: 'عميل ج',
            total: 70,
            paid: 0,
            due: 70,
            created: '2026-08-20 10:00:00',
          ),
          shipment(
            id: 'S5',
            status: 'مكتملة',
            customer: 'عميل ج',
            total: 900,
            paid: 900,
            due: 0,
            created: '2026-08-21 10:00:00',
          ),
        ],
        payments: <Payment>[
          payment(
            id: 'P1',
            amount: 100,
            method: 'كاش',
            created: '2026-09-02 09:00:00',
          ),
          payment(
            id: 'P2',
            amount: 50,
            method: 'بنك',
            created: '2026-09-02 11:00:00',
          ),
          payment(
            id: 'P3',
            amount: 30,
            method: 'كاش',
            created: '2026-08-30 11:00:00',
          ),
        ],
        expenses: <Expense>[
          expense(id: 'E1', amount: 40, created: '2026-09-03 08:00:00'),
          expense(id: 'E2', amount: 20, created: '2026-08-31 08:00:00'),
        ],
      );
    });

    test('aggregates period revenue and expenses', () {
      expect(report.revenue, 150);
      expect(report.expenses, 40);
      expect(report.net, 110);
    });

    test('groups revenue by method without dropping known methods', () {
      expect(report.revenueByMethod['كاش'], 100);
      expect(report.revenueByMethod['بنك'], 50);
      expect(report.revenueByMethod['آجل'], 0);
    });

    test('counts shipments that fall inside the period', () {
      expect(report.shipmentsCount, 3);
      expect(report.shipmentsByStatus, <String, int>{
        'مكتملة': 1,
        'قيد النقل': 1,
        'مسودة': 1,
      });
      expect(report.totalShipments, 3);
    });

    test('counts all completed shipments regardless of period', () {
      expect(report.completedCount, 2);
      expect(report.completedFees, 1400);
    });

    test('open dues exclude drafts and cancelled shipments', () {
      expect(report.openDue, 400);
    });

    test('ranks top customers by total fee', () {
      expect(report.topCustomers.length, 2);
      expect(report.topCustomers.first.name, 'عميل أ');
      expect(report.topCustomers.first.total, 580);
      expect(report.topCustomers.first.shipments, 2);
      expect(report.topCustomers.last.name, 'عميل ب');
    });

    test('builds a daily revenue timeline covering the whole period', () {
      expect(report.revenueTimeline.length, 10);
      expect(report.revenueTimeline.first.label, '09-01');
      expect(report.revenueTimeline.last.label, '09-10');
      final sum = report.revenueTimeline.fold<double>(
        0,
        (total, point) => total + point.amount,
      );
      expect(sum, 150);
      expect(report.revenueTimeline[1].amount, 150);
    });

    test('returns empty timeline data for a zero-activity period', () {
      final empty = ReportData.build(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 2),
        shipments: const <Shipment>[],
        payments: const <Payment>[],
        expenses: const <Expense>[],
      );

      expect(empty.revenue, 0);
      expect(empty.net, 0);
      expect(empty.shipmentsCount, 0);
      expect(empty.openDue, 0);
      expect(empty.topCustomers, isEmpty);
      expect(empty.revenueTimeline.length, 2);
      expect(empty.totalShipments, 0);
    });
  });
}
