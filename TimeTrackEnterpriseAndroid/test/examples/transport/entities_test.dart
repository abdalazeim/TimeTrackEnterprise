import 'package:flutter_test/flutter_test.dart';
import 'package:generic_template/examples/transport/domain/entities/goods_type.dart';
import 'package:generic_template/examples/transport/domain/entities/shipment.dart';
import 'package:generic_template/examples/transport/domain/entities/transport_meta.dart';
import 'package:generic_template/examples/transport/domain/entities/trip.dart';
import 'package:generic_template/examples/transport/domain/entities/value_readers.dart';

void main() {
  group('readers', () {
    test('parse numbers coming as text or numbers', () {
      expect(readNumber('1,250.5'), 1250.5);
      expect(readNumber(12), 12);
      expect(readNumber(null), 0);
      expect(readInteger('7'), 7);
      expect(readFlag('1'), isTrue);
      expect(readFlag('نعم'), isTrue);
      expect(readFlag(0), isFalse);
    });

    test('parse Arabic-Indic input digits', () {
      expect(parseInputNumber('١٢٣٤'), 1234);
      expect(parseInputNumber('۱۲٬۵۰۰'), 12500);
      expect(parseInputNumber('abc'), isNull);
    });

    test('parse dates with space and T separators', () {
      expect(readDate('2026-10-05 13:45:00'), DateTime(2026, 10, 5, 13, 45));
      expect(readDate('2026-10-05T13:45:00'), DateTime(2026, 10, 5, 13, 45));
      expect(readDate(''), isNull);
    });
  });

  group('Shipment', () {
    Map<String, dynamic> json({Object? status = 'قيد النقل'}) {
      return <String, dynamic>{
        'id': 'SHP-1001',
        'rog': 'ROG-9',
        'waybill': 'WB-77',
        'customer': 'شركة النور',
        'consignee': <String, dynamic>{
          'name': 'محمد علي',
          'phone': '0910000000',
          'notes': 'باب المتجر',
          'id': 'ID-5',
        },
        'shipper': <String, dynamic>{
          'name': 'شركة النور',
          'phone': '0920000000',
        },
        'from': 'طرابلس',
        'to': 'بنغازي',
        'goods': 'كرتون أجهزة',
        'qty': '4',
        'unit': 'كرتون',
        'wt': 120.5,
        'vol': '2.5',
        'dist': 1050,
        'disc': '10',
        'items': <dynamic>[
          <String, dynamic>{
            'goods': 'كرتون أجهزة',
            'qty': 4,
            'unit': 'كرتون',
            'wt': 120.5,
            'vol': 2.5,
            'disc': 10,
            'note': 'قابل للكسر',
          },
        ],
        'services': <dynamic>[0, 2],
        'notes': 'اتصال قبل الوصول',
        'method': 'آجل',
        'tripId': 'TRP-1',
        'vehicle': 'شاحنة 1',
        'driver': 'سالم',
        'status': status,
        'urgent': 1,
        'fee': <String, dynamic>{
          'base': 400,
          'weight': 60,
          'svc': 50,
          'discount': 10,
          'total': 500,
        },
        'feeTotal': 500,
        'paid': 200,
        'due': 0,
        'pay': <String, dynamic>{'state': 'جزئي'},
        'invoice': <String, dynamic>{'no': 'INV-3'},
        'dates': <String, dynamic>{
          'draft': '2026-10-01 09:00:00',
          'rec': '2026-10-02 09:30:00',
          'loaded': '2026-10-03T08:00:00',
        },
        'pod': <String, dynamic>{
          'receiver': 'محمد علي',
          'recId': 'ID-5',
          'by': 'سالم',
          'note': 'سليم',
          'sig': 'data:image/png;base64,AAAA',
          'date': '2026-10-06 12:00:00',
        },
      };
    }

    test('parses the live shipment contract', () {
      final shipment = Shipment.fromJson(json());

      expect(shipment.id, 'SHP-1001');
      expect(shipment.customer, 'شركة النور');
      expect(shipment.consignee.name, 'محمد علي');
      expect(shipment.consignee.cardId, 'ID-5');
      expect(shipment.quantity, 4);
      expect(shipment.weight, 120.5);
      expect(shipment.items.single.note, 'قابل للكسر');
      expect(shipment.services, <int>[0, 2]);
      expect(shipment.urgent, isTrue);
      expect(shipment.isDraft, isFalse);
      expect(shipment.paymentState, 'جزئي');
      expect(shipment.invoiceNumber, 'INV-3');
      expect(shipment.dates.received, DateTime(2026, 10, 2, 9, 30));
      expect(shipment.dates.receivedOrCreated, DateTime(2026, 10, 2, 9, 30));
      expect(shipment.fee.services, 50);
      expect(shipment.totalFee, 500);
      expect(shipment.remaining, 300);
      expect(shipment.isLoaded, isTrue);
      expect(shipment.pod?.hasSignature, isTrue);
    });

    test('treats draft status as a draft and derives due', () {
      final shipment = Shipment.fromJson(json(status: 'مسودة'));

      expect(shipment.isDraft, isTrue);
      expect(shipment.isLoaded, isFalse);
      expect(shipment.remaining, 300);
      expect(shipment.totalFee, 500);
    });

    test('uses fee.total when feeTotal is absent', () {
      final raw = json();
      raw.remove('feeTotal');
      raw.remove('due');

      final shipment = Shipment.fromJson(raw);

      expect(shipment.totalFee, 500);
      expect(shipment.remaining, 300);
    });

    test('handles missing optional values safely', () {
      final shipment = Shipment.fromJson(<String, dynamic>{'id': 'SHP-2'});

      expect(shipment.customer, isEmpty);
      expect(shipment.items, isEmpty);
      expect(shipment.status, 'مسودة');
      expect(shipment.isDraft, isTrue);
      expect(shipment.pod, isNull);
      expect(shipment.remaining, 0);
    });
  });

  group('Trip', () {
    test('parses stops from text and numbers from strings', () {
      final trip = Trip.fromJson(<String, dynamic>{
        'id': 'TRP-1',
        'name': 'رحلة الشمال',
        'from': 'طرابلس',
        'to': 'مصراتة',
        'vehicle': 'شاحنة 12',
        'driver': 'سالم',
        'capKg': '8000',
        'status': 'في الطريق',
        'stops': 'طرابلس، الخمس، مصراتة',
        'closed': 0,
        'dates': <String, dynamic>{
          'plan': '2026-10-01 07:00:00',
          'load': '2026-10-01 08:00:00',
        },
      });

      expect(trip.capacityKg, 8000);
      expect(trip.stops, <String>['طرابلس', 'الخمس', 'مصراتة']);
      expect(trip.canAdvance, isTrue);
      expect(trip.dates.plan, DateTime(2026, 10, 1, 7));
    });

    test('closed or final trips cannot advance', () {
      final trip = Trip.fromJson(<String, dynamic>{
        'id': 'TRP-2',
        'status': 'وصلت للوجهة',
        'closed': 1,
      });

      expect(trip.closed, isTrue);
      expect(trip.isClosed, isTrue);
      expect(trip.canAdvance, isFalse);
    });

    test('parses array stops', () {
      final trip = Trip.fromJson(<String, dynamic>{
        'id': 'TRP-3',
        'stops': <dynamic>['الزاوية', '', '  سبها '],
      });

      expect(trip.stops, <String>['الزاوية', 'سبها']);
    });
  });

  group('GoodsType', () {
    test('parses hazard flag and builds payload', () {
      final goods = GoodsType.fromJson(<String, dynamic>{
        'id': 'G-1',
        'name': 'أسطوانات',
        'cat': 'مواد خطرة',
        'haz': 1,
        'unit': 'طرد',
        'store': 'مستودع 2',
        'note': 'تهوية',
      });

      expect(goods.hazardous, isTrue);
      expect(goods.category, 'مواد خطرة');
      expect(goods.toPayload(), <String, dynamic>{
        'name': 'أسطوانات',
        'cat': 'مواد خطرة',
        'haz': 1,
        'unit': 'طرد',
        'store': 'مستودع 2',
        'note': 'تهوية',
      });
    });
  });

  group('TransportMeta', () {
    test('falls back to web defaults when empty', () {
      final meta = TransportMeta.fromJson(const <String, dynamic>{});

      expect(meta.flow.first, 'مسودة');
      expect(meta.units, contains('كرتون'));
      expect(meta.nextShipmentStatus('مسودة'), 'تم الاستلام');
      expect(meta.nextShipmentStatus('مكتملة'), isEmpty);
      expect(meta.nextShipmentStatus('ملغاة'), isEmpty);
      expect(meta.nextTripStatus('مخططة'), 'تم التحميل');
      expect(meta.nextTripStatus('وصلت للوجهة'), isEmpty);
    });

    test('parses services from pair lists', () {
      final meta = TransportMeta.fromJson(<String, dynamic>{
        'services': <dynamic>[
          <dynamic>['تغليف', '25'],
          <String, dynamic>{'name': 'تأمين', 'price': 10},
        ],
      });

      expect(meta.services.length, 2);
      expect(meta.services.first.name, 'تغليف');
      expect(meta.services.first.price, 25);
      expect(meta.services.last.price, 10);
    });

    test('uses non-empty server lists over fallback', () {
      final meta = TransportMeta.fromJson(<String, dynamic>{
        'cities': <dynamic>['مدينة أ', 'مدينة ب'],
        'methods': <dynamic>['نقدي'],
      });

      expect(meta.cities, <String>['مدينة أ', 'مدينة ب']);
      expect(meta.methods, <String>['نقدي']);
    });
  });
}
