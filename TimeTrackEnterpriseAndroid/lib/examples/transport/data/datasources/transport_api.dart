import '../../../../core/network/api_client.dart';
import 'transport_api_endpoints.dart';

/// كل استدعاءات وحدة النقل كما تستخدمها واجهة الويب الحيّة.
class TransportApi {
  TransportApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> meta() =>
      _client.getMap(TransportApiEndpoints.transportMeta);

  Future<List<dynamic>> shipments() => _client.getList(
        TransportApiEndpoints.shipments,
        query: <String, dynamic>{'drafts': 1},
      );

  Future<List<dynamic>> goods() => _client.getList(TransportApiEndpoints.goods);

  Future<List<dynamic>> trips() => _client.getList(TransportApiEndpoints.trips);

  Future<List<dynamic>> customers() =>
      _client.getList(TransportApiEndpoints.customers);

  Future<List<dynamic>> vehicles() =>
      _client.getList(TransportApiEndpoints.vehicles);

  Future<List<dynamic>> drivers() =>
      _client.getList(TransportApiEndpoints.drivers);

  Future<List<dynamic>> routes() =>
      _client.getList(TransportApiEndpoints.routes);

  Future<List<dynamic>> payments() =>
      _client.getList(TransportApiEndpoints.payments);

  Future<List<dynamic>> expenses() =>
      _client.getList(TransportApiEndpoints.expenses);

  Future<void> createShipment(Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.shipmentsAdd, body: body);

  Future<void> saveDraft(Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.draftsSave, body: body);

  /// واجهة الويب تستخدم POST على مسار التعديل، والخادم يقبله فعليًا.
  Future<void> editShipment(String id, Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.shipmentEdit(id), body: body);

  Future<void> submitDraft(String id, [Map<String, dynamic>? payload]) =>
      _client.postVoid(TransportApiEndpoints.draftSubmit(id), body: payload);

  Future<void> advanceShipment(String id) =>
      _client.postVoid(TransportApiEndpoints.shipmentAdvance(id));

  Future<void> setShipmentException(String id, Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.shipmentException(id), body: body);

  Future<void> savePod(String id, Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.shipmentPod(id), body: body);

  Future<void> unloadShipment(String id) =>
      _client.postVoid(TransportApiEndpoints.shipmentUnload(id));

  Future<void> deleteShipment(String id) =>
      _client.deleteVoid(TransportApiEndpoints.shipmentDelete(id));

  Future<void> createGoods(Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.goodsAdd, body: body);

  Future<void> updateGoods(String id, Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.goodsUpdate(id), body: body);

  Future<void> deleteGoods(String id) =>
      _client.deleteVoid(TransportApiEndpoints.goodsDelete(id));

  Future<void> createTrip(Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.tripsAdd, body: body);

  Future<void> updateTrip(String id, Map<String, dynamic> body) =>
      _client.postVoid(TransportApiEndpoints.tripEdit(id), body: body);

  Future<void> deleteTrip(String id) =>
      _client.deleteVoid(TransportApiEndpoints.tripDelete(id));

  Future<void> advanceTrip(String id) =>
      _client.postVoid(TransportApiEndpoints.tripAdvance(id));

  Future<void> closeTrip(String id) =>
      _client.postVoid(TransportApiEndpoints.tripClose(id));

  Future<void> reopenTrip(String id) =>
      _client.postVoid(TransportApiEndpoints.tripReopen(id));

  Future<void> linkShipments(String id, List<String> shipmentIds) =>
      _client.postVoid(
        TransportApiEndpoints.tripLink(id),
        body: <String, dynamic>{'shipIds': shipmentIds},
      );

  Future<void> loadShipments(String id, List<String> shipmentIds) =>
      _client.postVoid(
        TransportApiEndpoints.tripLoad(id),
        body: <String, dynamic>{'shipIds': shipmentIds},
      );
}
