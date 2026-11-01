import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/cached_data.dart';
import '../../domain/entities/goods_type.dart';
import '../../domain/entities/payment_expense.dart';
import '../../domain/entities/reference_entities.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/transport_repository.dart';
import '../datasources/transport_api.dart';
import '../local/transport_cache.dart';

class TransportRepositoryImpl implements TransportRepository {
  TransportRepositoryImpl({
    required TransportApi api,
    required TransportCache cache,
  })  : _api = api,
        _cache = cache;

  final TransportApi _api;
  final TransportCache _cache;

  @override
  Future<TransportMeta> meta() async {
    try {
      final json = await _api.meta();
      return TransportMeta.fromJson(json);
    } on ApiException {
      return TransportMeta.fallback;
    }
  }

  @override
  Future<CachedData<List<Shipment>>> shipments() => _load<Shipment>(
        remote: _api.shipments,
        model: TransportCache.shipments,
        parse: (json) {
          final shipment = Shipment.fromJson(json);
          return shipment.id.isEmpty ? null : shipment;
        },
      );

  @override
  Future<CachedData<List<GoodsType>>> goods() => _load<GoodsType>(
        remote: _api.goods,
        model: TransportCache.goods,
        parse: (json) {
          final item = GoodsType.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<Trip>>> trips() => _load<Trip>(
        remote: _api.trips,
        model: TransportCache.trips,
        parse: (json) {
          final trip = Trip.fromJson(json);
          return trip.id.isEmpty ? null : trip;
        },
      );

  @override
  Future<CachedData<List<Customer>>> customers() => _load<Customer>(
        remote: _api.customers,
        model: TransportCache.customers,
        parse: (json) {
          final item = Customer.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<Vehicle>>> vehicles() => _load<Vehicle>(
        remote: _api.vehicles,
        model: TransportCache.vehicles,
        parse: (json) {
          final item = Vehicle.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<Driver>>> drivers() => _load<Driver>(
        remote: _api.drivers,
        model: TransportCache.drivers,
        parse: (json) {
          final item = Driver.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<RouteInfo>>> routes() => _load<RouteInfo>(
        remote: _api.routes,
        model: TransportCache.routes,
        parse: (json) {
          final item = RouteInfo.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<Payment>>> payments() => _load<Payment>(
        remote: _api.payments,
        model: TransportCache.payments,
        parse: (json) {
          final item = Payment.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  @override
  Future<CachedData<List<Expense>>> expenses() => _load<Expense>(
        remote: _api.expenses,
        model: TransportCache.expenses,
        parse: (json) {
          final item = Expense.fromJson(json);
          return item.id.isEmpty ? null : item;
        },
      );

  Future<CachedData<List<T>>> _load<T>({
    required Future<List<dynamic>> Function() remote,
    required String model,
    required T? Function(Map<String, dynamic> json) parse,
  }) async {
    try {
      final raw = await remote();
      final maps = raw
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
      await _cache.write(model, maps);
      return CachedData<List<T>>(
        value: maps.map(parse).whereType<T>().toList(growable: false),
      );
    } on ApiException {
      final cached = await _cache.read(model);
      if (cached.isEmpty) rethrow;
      return CachedData<List<T>>(
        value: cached.map(parse).whereType<T>().toList(growable: false),
        fromCache: true,
      );
    }
  }

  @override
  Future<void> createShipment(Map<String, dynamic> payload) =>
      _api.createShipment(payload);

  @override
  Future<void> saveDraft(Map<String, dynamic> payload) =>
      _api.saveDraft(payload);

  @override
  Future<void> editShipment(String id, Map<String, dynamic> payload) =>
      _api.editShipment(id, payload);

  @override
  Future<void> submitDraft(String id, [Map<String, dynamic>? payload]) =>
      _api.submitDraft(id, payload);

  @override
  Future<void> advanceShipment(String id) => _api.advanceShipment(id);

  @override
  Future<void> setShipmentException(
    String id, {
    required String status,
    required String note,
  }) =>
      _api.setShipmentException(
        id,
        <String, dynamic>{'status': status, 'note': note},
      );

  @override
  Future<void> savePod(String id, Map<String, dynamic> payload) =>
      _api.savePod(id, payload);

  @override
  Future<void> unloadShipment(String id) => _api.unloadShipment(id);

  @override
  Future<void> deleteShipment(String id) => _api.deleteShipment(id);

  @override
  Future<void> createGoods(Map<String, dynamic> payload) =>
      _api.createGoods(payload);

  @override
  Future<void> updateGoods(String id, Map<String, dynamic> payload) =>
      _api.updateGoods(id, payload);

  @override
  Future<void> deleteGoods(String id) => _api.deleteGoods(id);

  @override
  Future<void> createTrip(Map<String, dynamic> payload) =>
      _api.createTrip(payload);

  @override
  Future<void> updateTrip(String id, Map<String, dynamic> payload) =>
      _api.updateTrip(id, payload);

  @override
  Future<void> deleteTrip(String id) => _api.deleteTrip(id);

  @override
  Future<void> advanceTrip(String id) => _api.advanceTrip(id);

  @override
  Future<void> closeTrip(String id) => _api.closeTrip(id);

  @override
  Future<void> reopenTrip(String id) => _api.reopenTrip(id);

  @override
  Future<void> linkShipments(String tripId, List<String> shipmentIds) =>
      _api.linkShipments(tripId, shipmentIds);

  @override
  Future<void> loadShipments(String tripId, List<String> shipmentIds) =>
      _api.loadShipments(tripId, shipmentIds);
}
