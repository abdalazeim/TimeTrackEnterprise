import 'value_readers.dart';

/// طرف الشحنة (المرسل أو المستلم).
class ShipmentParty {
  const ShipmentParty({
    required this.name,
    this.phone,
    this.notes,
    this.cardId,
  });

  final String name;
  final String? phone;
  final String? notes;
  final String? cardId;

  factory ShipmentParty.fromJson(Object? value) {
    final json = readObject(value);
    return ShipmentParty(
      name: readText(json['name']),
      phone: readTextOrNull(json['phone']),
      notes: readTextOrNull(json['notes']),
      cardId: readTextOrNull(json['id']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'phone': phone ?? '',
        'notes': notes ?? '',
      };
}

/// بند واحد من بنود البضاعة.
class ShipmentItem {
  const ShipmentItem({
    required this.goods,
    required this.qty,
    required this.unit,
    required this.weight,
    required this.volume,
    required this.discount,
    this.note,
  });

  final String goods;
  final double qty;
  final String unit;
  final double weight;
  final double volume;
  final double discount;
  final String? note;

  factory ShipmentItem.fromJson(Object? value) {
    final json = readObject(value);
    return ShipmentItem(
      goods: readText(json['goods'], fallback: 'عام'),
      qty: readNumber(json['qty']),
      unit: readText(json['unit']),
      weight: readNumber(json['wt']),
      volume: readNumber(json['vol']),
      discount: readNumber(json['disc']),
      note: readTextOrNull(json['note']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'goods': goods,
        'qty': qty,
        'unit': unit,
        'wt': weight,
        'vol': volume,
        'disc': discount,
        'note': note ?? '',
      };
}

/// تفصيل الأجرة كما يعيده الخادم.
class ShipmentFee {
  const ShipmentFee({
    required this.base,
    required this.weight,
    required this.services,
    required this.discount,
    required this.total,
  });

  final double base;
  final double weight;
  final double services;
  final double discount;
  final double total;

  factory ShipmentFee.fromJson(Object? value) {
    final json = readObject(value);
    return ShipmentFee(
      base: readNumber(json['base']),
      weight: readNumber(json['weight']),
      services: readNumber(json['svc']),
      discount: readNumber(json['discount']),
      total: readNumber(json['total']),
    );
  }

  static const ShipmentFee empty = ShipmentFee(
    base: 0,
    weight: 0,
    services: 0,
    discount: 0,
    total: 0,
  );
}

/// مراحل الشحنة الزمنية.
class ShipmentDates {
  const ShipmentDates({
    this.created,
    this.received,
    this.ready,
    this.loaded,
    this.departed,
    this.arrived,
    this.delivered,
    this.closed,
    this.loadedBy,
  });

  final DateTime? created;
  final DateTime? received;
  final DateTime? ready;
  final DateTime? loaded;
  final DateTime? departed;
  final DateTime? arrived;
  final DateTime? delivered;
  final DateTime? closed;
  final String? loadedBy;

  factory ShipmentDates.fromJson(Object? value) {
    final json = readObject(value);
    return ShipmentDates(
      created: readDate(json['draft']),
      received: readDate(json['rec']),
      ready: readDate(json['ready']),
      loaded: readDate(json['loaded']),
      departed: readDate(json['departed']),
      arrived: readDate(json['arrived']),
      delivered: readDate(json['deliv']),
      closed: readDate(json['closed']),
      loadedBy: readTextOrNull(json['loadedBy']),
    );
  }

  DateTime? get receivedOrCreated => received ?? created;

  List<(String, DateTime?)> get steps => <(String, DateTime?)>[
        ('إنشاء السجل', created),
        ('استلام البضاعة', received),
        ('جاهزة للشحن', ready),
        ('التحميل على الرحلة', loaded),
        ('انطلاق الرحلة', departed),
        ('الوصول للوجهة', arrived),
        ('التسليم للمستلم', delivered),
        ('إقفال الشحنة', closed),
      ];
}

/// إثبات التسليم.
class ShipmentPod {
  const ShipmentPod({
    this.receiver,
    this.cardId,
    this.by,
    this.note,
    this.signature,
    this.date,
  });

  final String? receiver;
  final String? cardId;
  final String? by;
  final String? note;
  final String? signature;
  final DateTime? date;

  bool get hasSignature =>
      signature != null && signature!.startsWith('data:image');

  factory ShipmentPod.fromJson(Object? value) {
    final json = readObject(value);
    return ShipmentPod(
      receiver: readTextOrNull(json['receiver']),
      cardId: readTextOrNull(json['recId']),
      by: readTextOrNull(json['by']),
      note: readTextOrNull(json['note']),
      signature: readTextOrNull(json['sig']),
      date: readDate(json['date']),
    );
  }
}

/// شحنة كما تعيدها قائمة `/shipments/`.
class Shipment {
  const Shipment({
    required this.id,
    required this.customer,
    required this.consignee,
    required this.shipper,
    required this.from,
    required this.to,
    required this.goods,
    required this.quantity,
    required this.unit,
    required this.weight,
    required this.volume,
    required this.distance,
    required this.discount,
    required this.items,
    required this.services,
    required this.fee,
    required this.paid,
    required this.due,
    required this.paymentState,
    required this.dates,
    required this.status,
    this.rog,
    this.waybill,
    this.invoiceNumber,
    this.notes,
    this.method,
    this.tripId,
    this.vehicle,
    this.driver,
    this.pod,
    this.feeTotal,
    this.urgent = false,
    this.isDraft = false,
  });

  final String id;
  final String? rog;
  final String? waybill;
  final String? invoiceNumber;
  final String customer;
  final ShipmentParty consignee;
  final ShipmentParty shipper;
  final String from;
  final String to;
  final String goods;
  final double quantity;
  final String unit;
  final double weight;
  final double volume;
  final double distance;
  final double discount;
  final List<ShipmentItem> items;
  final List<int> services;
  final String? notes;
  final String? method;
  final String? tripId;
  final String? vehicle;
  final String? driver;
  final String status;
  final bool urgent;
  final bool isDraft;
  final ShipmentFee fee;
  final double paid;
  final double due;
  final String paymentState;
  final ShipmentDates dates;
  final ShipmentPod? pod;

  /// يُستخدم في نموذج التعديل لإعادة بناء الأجرة.
  final double? feeTotal;

  double get remaining {
    if (due > 0) return due;
    final total = fee.total > 0 ? fee.total : (feeTotal ?? 0);
    final rest = total - paid;
    return rest > 0 ? rest : 0;
  }

  double get totalFee => fee.total > 0 ? fee.total : (feeTotal ?? 0);

  bool get isLoaded => loadedStatuses.contains(status);

  static const List<String> loadedStatuses = <String>[
    'تم الشحن',
    'قيد النقل',
    'وصلت للوجهة',
    'جاهزة للتسليم',
    'تم التسليم',
    'مكتملة',
  ];

  static const List<String> finalStatuses = <String>[
    'مكتملة',
    'ملغاة',
    'مرتجع',
    'فشل التسليم',
  ];

  factory Shipment.fromJson(Map<String, dynamic> json) {
    final feeJson = readObject(json['fee']);
    final paid = readNumber(json['paid']);
    final feeTotal = readNumber(json['feeTotal']).abs() > 0
        ? readNumber(json['feeTotal'])
        : readNumber(feeJson['total']);
    final dueRaw = json['due'];
    final due = dueRaw == null
        ? (feeTotal - paid > 0 ? feeTotal - paid : 0.0)
        : readNumber(dueRaw);

    return Shipment(
      id: readText(json['id']),
      rog: readTextOrNull(json['rog']),
      waybill: readTextOrNull(json['waybill']),
      invoiceNumber: readTextOrNull(readObject(json['invoice'])['no']),
      customer: readText(json['customer']),
      consignee: ShipmentParty.fromJson(json['consignee']),
      shipper: ShipmentParty.fromJson(json['shipper']),
      from: readText(json['from']),
      to: readText(json['to']),
      goods: readText(json['goods']),
      quantity: readNumber(json['qty']),
      unit: readText(json['unit']),
      weight: readNumber(json['wt']),
      volume: readNumber(json['vol']),
      distance: readNumber(json['dist']),
      discount: readNumber(json['disc']),
      items: readArray(json['items'])
          .map(ShipmentItem.fromJson)
          .toList(growable: false),
      services:
          readArray(json['services']).map(readInteger).toList(growable: false),
      notes: readTextOrNull(json['notes']),
      method: readTextOrNull(json['method']),
      tripId: readTextOrNull(json['tripId']),
      vehicle: readTextOrNull(json['vehicle']),
      driver: readTextOrNull(json['driver']),
      status: readText(json['status'], fallback: 'مسودة'),
      urgent: readFlag(json['urgent']),
      isDraft: readFlag(json['draft']) ||
          readText(json['status'], fallback: 'مسودة') == 'مسودة',
      fee: ShipmentFee.fromJson(feeJson),
      feeTotal: feeTotal,
      paid: paid,
      due: due,
      paymentState: readText(
        readObject(json['pay'])['state'],
        fallback: 'غير مدفوع',
      ),
      dates: ShipmentDates.fromJson(json['dates']),
      pod: readObject(json['pod']).isEmpty
          ? null
          : ShipmentPod.fromJson(json['pod']),
    );
  }
}
