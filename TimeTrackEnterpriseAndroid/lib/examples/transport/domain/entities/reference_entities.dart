import 'value_readers.dart';

/// عميل من المرجع `/customers/`.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.city,
    this.type,
  });

  final String id;
  final String name;
  final String? phone;
  final String? city;
  final String? type;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: readText(json['id']),
      name: readText(json['name']),
      phone: readTextOrNull(json['phone']),
      city: readTextOrNull(json['city']),
      type: readTextOrNull(json['type']),
    );
  }
}

/// مركبة من المرجع `/vehicles/`.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.plate,
    required this.capacityKg,
    required this.status,
  });

  final String id;
  final String name;
  final String plate;
  final double capacityKg;
  final String status;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: readText(json['id']),
      name: readText(json['name']),
      plate: readText(json['plate']),
      capacityKg: readNumber(json['capKg']),
      status: readText(json['status']),
    );
  }

  factory Vehicle.empty(String name) => Vehicle(
        id: '',
        name: name,
        plate: '',
        capacityKg: 0,
        status: '',
      );
}

/// سائق من المرجع `/drivers/`.
class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
  });

  final String id;
  final String name;
  final String phone;
  final String status;

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: readText(json['id']),
      name: readText(json['name']),
      phone: readText(json['phone']),
      status: readText(json['status']),
    );
  }

  factory Driver.empty(String name) => Driver(
        id: '',
        name: name,
        phone: '',
        status: '',
      );
}

/// مسار بين مدينتين، يُستخدم لحساب المسافة والأجرة.
class RouteInfo {
  const RouteInfo({
    required this.id,
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.price,
  });

  final String id;
  final String from;
  final String to;
  final double distanceKm;
  final double price;

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: readText(json['id']),
      from: readText(json['from']),
      to: readText(json['to']),
      distanceKm: readNumber(json['dist']),
      price: readNumber(json['price']),
    );
  }

  bool matches(String from, String to) =>
      (this.from == from && this.to == to) ||
      (this.from == to && this.to == from);
}
