import 'value_readers.dart';

/// خدمة تُضاف إلى الشحنة مع سعرها المعروض.
class TransportService {
  const TransportService({required this.name, required this.price});

  final String name;
  final double price;
}

/// قوائم القيم المرجعية القادمة من `/modules/transport/meta/`.
///
/// عند تعذّر الوصول للخادم تُستخدم القيم الافتراضية نفسها التي تعتمدها
/// واجهة الويب، حتى تبقى النماذج قابلة للاستخدام دون اتصال.
class TransportMeta {
  const TransportMeta({
    required this.flow,
    required this.flowShort,
    required this.exceptions,
    required this.tripFlow,
    required this.methods,
    required this.paymentStates,
    required this.services,
    required this.cities,
    required this.goodsCategories,
    required this.units,
    required this.customerTypes,
  });

  final List<String> flow;
  final List<String> flowShort;
  final List<String> exceptions;
  final List<String> tripFlow;
  final List<String> methods;
  final List<String> paymentStates;
  final List<TransportService> services;
  final List<String> cities;
  final List<String> goodsCategories;
  final List<String> units;
  final List<String> customerTypes;

  factory TransportMeta.fromJson(Map<String, dynamic> json) {
    const fallback = TransportMeta.fallback;

    final flow = _stringList(json['flow'], fallback.flow);
    final services = _services(json['services'], fallback.services);

    return TransportMeta(
      flow: flow,
      flowShort: _stringList(
        json['flowShort'] ?? json['flow_short'],
        fallback.flowShort,
      ),
      exceptions: _stringList(json['exceptions'], fallback.exceptions),
      tripFlow:
          _stringList(json['tripFlow'] ?? json['trip_flow'], fallback.tripFlow),
      methods: _stringList(json['methods'], fallback.methods),
      paymentStates: _stringList(
        json['payStates'] ?? json['pay_states'],
        fallback.paymentStates,
      ),
      services: services,
      cities: _stringList(json['cities'], fallback.cities),
      goodsCategories: _stringList(
        json['goodcats'] ?? json['goodsCategories'],
        fallback.goodsCategories,
      ),
      units: _stringList(json['units'], fallback.units),
      customerTypes: _stringList(
        json['customerTypes'] ?? json['customer_types'],
        fallback.customerTypes,
      ),
    );
  }

  /// القيم الاحتياطية المطابقة لواجهة الويب.
  static const TransportMeta fallback = TransportMeta(
    flow: <String>[
      'مسودة',
      'تم الاستلام',
      'جاهزة للشحن',
      'تم الشحن',
      'قيد النقل',
      'وصلت للوجهة',
      'جاهزة للتسليم',
      'تم التسليم',
      'مكتملة',
    ],
    flowShort: <String>[
      'مسودة',
      'استلام',
      'جاهزة',
      'تحميل',
      'نقل',
      'وصول',
      'تسليم جاهز',
      'تم التسليم',
      'مكتملة',
    ],
    exceptions: <String>['معلقة', 'مؤجلة', 'ملغاة', 'فشل التسليم'],
    tripFlow: <String>['مخططة', 'تم التحميل', 'في الطريق', 'وصلت للوجهة'],
    methods: <String>['آجل', 'كاش', 'بنك', 'شيك', 'بطاقة مصرفية'],
    paymentStates: <String>['غير مدفوع', 'جزئي', 'مدفوع'],
    services: <TransportService>[
      TransportService(name: 'استلام من المستودع', price: 0),
      TransportService(name: 'توصيل حتى باب العميل', price: 30),
      TransportService(name: 'رفع وتنزيل', price: 50),
      TransportService(name: 'تأمين بوليصة', price: 15),
      TransportService(name: 'تغليف وتعبئة', price: 20),
    ],
    cities: <String>[
      'طرابلس',
      'بنغازي',
      'مصراتة',
      'الزاوية',
      'سبها',
      'البيضاء',
      'طبرق',
      'زليتن',
      'الخميس',
      'غريان',
      'المرج',
      'درنة',
    ],
    goodsCategories: <String>[
      'عام',
      'مواد غذائية',
      'إلكترونيات',
      'أثاث',
      'مواد بناء',
      'أدوية',
      'ملابس',
      'قطع غيار',
    ],
    units: <String>['كرتون', 'طقم', 'بالة', 'طرد', 'طن', 'متر', 'حاوية'],
    customerTypes: <String>[
      'شركة',
      'مؤسسة',
      'فرد',
      'متجر',
      'سوق',
      'مخزن',
      'مصنع',
    ],
  );

  String nextShipmentStatus(String current) {
    if (exceptions.contains(current)) return '';
    final index = flow.indexOf(current);
    if (index < 0 || index >= flow.length - 1) return '';
    return flow[index + 1];
  }

  String nextTripStatus(String current) {
    final index = tripFlow.indexOf(current);
    if (index < 0 || index >= tripFlow.length - 1) return '';
    return tripFlow[index + 1];
  }

  static List<String> _stringList(Object? value, List<String> fallback) {
    final list = readArray(value)
        .map((item) => readText(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return list.isEmpty ? fallback : list;
  }

  static List<TransportService> _services(
    Object? value,
    List<TransportService> fallback,
  ) {
    final list = <TransportService>[];
    for (final item in readArray(value)) {
      if (item is List && item.isNotEmpty) {
        final name = readText(item.first);
        if (name.isEmpty) continue;
        final price = item.length > 1 ? readNumber(item[1]) : 0.0;
        list.add(TransportService(name: name, price: price));
      } else if (item is Map) {
        final map = item.cast<String, dynamic>();
        final name = readText(map['name']);
        if (name.isEmpty) continue;
        list.add(
          TransportService(name: name, price: readNumber(map['price'])),
        );
      }
    }
    return list.isEmpty ? fallback : list;
  }
}
