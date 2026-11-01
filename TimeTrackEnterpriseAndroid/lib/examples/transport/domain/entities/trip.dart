import 'value_readers.dart';

/// مراحل الرحلة الزمنية.
class TripDates {
  const TripDates({this.plan, this.load, this.depart, this.arrive});

  final DateTime? plan;
  final DateTime? load;
  final DateTime? depart;
  final DateTime? arrive;

  factory TripDates.fromJson(Object? value) {
    final json = readObject(value);
    return TripDates(
      plan: readDate(json['plan']),
      load: readDate(json['load']),
      depart: readDate(json['depart']),
      arrive: readDate(json['arrive']),
    );
  }
}

/// رحلة من `/trips/`.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    required this.vehicle,
    required this.driver,
    required this.capacityKg,
    required this.status,
    required this.stops,
    required this.dates,
    this.note,
    this.closed = false,
  });

  final String id;
  final String name;
  final String from;
  final String to;
  final String vehicle;
  final String driver;
  final double capacityKg;
  final String status;
  final List<String> stops;
  final TripDates dates;
  final String? note;
  final bool closed;

  bool get isClosed => closed;

  bool get canAdvance =>
      !closed &&
      status != 'وصلت للوجهة' &&
      status != 'مكتملة' &&
      status != 'ملغاة';

  factory Trip.fromJson(Map<String, dynamic> json) {
    final stopsRaw = json['stops'];
    final stops = <String>[];
    if (stopsRaw is List) {
      for (final item in stopsRaw) {
        final value = readText(item);
        if (value.isNotEmpty) stops.add(value);
      }
    } else {
      final text = readText(stopsRaw);
      if (text.isNotEmpty) {
        stops.addAll(
          text
              .split(RegExp('[,،]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
    }

    return Trip(
      id: readText(json['id']),
      name: readText(json['name']),
      from: readText(json['from']),
      to: readText(json['to']),
      vehicle: readText(json['vehicle']),
      driver: readText(json['driver']),
      capacityKg: readNumber(json['capKg']),
      status: readText(json['status'], fallback: 'مخططة'),
      stops: stops,
      dates: TripDates.fromJson(json['dates']),
      note: readTextOrNull(json['note']),
      closed: readFlag(json['closed']),
    );
  }

  Map<String, dynamic> toPayload({
    required String plan,
  }) =>
      <String, dynamic>{
        'name': name,
        'from': from,
        'to': to,
        'vehicle': vehicle,
        'driver': driver,
        'capKg': capacityKg,
        'plan': plan,
        'stops': stops.join('، '),
        'note': note ?? '',
      };
}
