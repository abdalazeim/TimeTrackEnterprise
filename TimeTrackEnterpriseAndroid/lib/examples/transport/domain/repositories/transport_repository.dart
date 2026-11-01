import '../entities/cached_data.dart';
import '../entities/goods_type.dart';
import '../entities/payment_expense.dart';
import '../entities/reference_entities.dart';
import '../entities/shipment.dart';
import '../entities/transport_meta.dart';
import '../entities/trip.dart';

/// عقد بيانات وحدة النقل.
abstract interface class TransportRepository {
  Future<TransportMeta> meta();

  Future<CachedData<List<Shipment>>> shipments();
  Future<CachedData<List<GoodsType>>> goods();
  Future<CachedData<List<Trip>>> trips();
  Future<CachedData<List<Customer>>> customers();
  Future<CachedData<List<Vehicle>>> vehicles();
  Future<CachedData<List<Driver>>> drivers();
  Future<CachedData<List<RouteInfo>>> routes();
  Future<CachedData<List<Payment>>> payments();
  Future<CachedData<List<Expense>>> expenses();

  Future<void> createShipment(Map<String, dynamic> payload);
  Future<void> saveDraft(Map<String, dynamic> payload);
  Future<void> editShipment(String id, Map<String, dynamic> payload);
  Future<void> submitDraft(String id, [Map<String, dynamic>? payload]);
  Future<void> advanceShipment(String id);
  Future<void> setShipmentException(
    String id, {
    required String status,
    required String note,
  });
  Future<void> savePod(String id, Map<String, dynamic> payload);
  Future<void> unloadShipment(String id);
  Future<void> deleteShipment(String id);

  Future<void> createGoods(Map<String, dynamic> payload);
  Future<void> updateGoods(String id, Map<String, dynamic> payload);
  Future<void> deleteGoods(String id);

  Future<void> createTrip(Map<String, dynamic> payload);
  Future<void> updateTrip(String id, Map<String, dynamic> payload);
  Future<void> deleteTrip(String id);
  Future<void> advanceTrip(String id);
  Future<void> closeTrip(String id);
  Future<void> reopenTrip(String id);
  Future<void> linkShipments(String tripId, List<String> shipmentIds);
  Future<void> loadShipments(String tripId, List<String> shipmentIds);
}
