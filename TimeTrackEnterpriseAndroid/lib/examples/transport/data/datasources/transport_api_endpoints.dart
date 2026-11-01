/// API paths owned by the optional transport example.
class TransportApiEndpoints {
  const TransportApiEndpoints._();

  static const String transport = '/api/v1/modules/transport';

  static const String transportMeta = '$transport/meta/';
  static const String shipments = '$transport/shipments/';
  static const String shipmentsAdd = '$transport/shipments/add/';
  static String shipmentEdit(String id) => '$transport/shipments/edit/$id/';
  static String shipmentDelete(String id) => '$transport/shipments/$id/delete/';
  static String shipmentAdvance(String id) =>
      '$transport/shipments/$id/advance/';
  static String shipmentException(String id) =>
      '$transport/shipments/$id/except/';
  static String shipmentPod(String id) => '$transport/shipments/$id/pod/';
  static String shipmentUnload(String id) => '$transport/shipments/$id/unload/';

  static const String draftsSave = '$transport/drafts/save/';
  static String draftSubmit(String id) => '$transport/drafts/$id/submit/';

  static const String goods = '$transport/goods/';
  static const String goodsAdd = '$transport/goods/add/';
  static String goodsUpdate(String id) => '$transport/goods/$id/';
  static String goodsDelete(String id) => '$transport/goods/$id/delete/';

  static const String trips = '$transport/trips/';
  static const String tripsAdd = '$transport/trips/add/';
  static String tripEdit(String id) => '$transport/trips/$id/edit/';
  static String tripDelete(String id) => '$transport/trips/$id/delete/';
  static String tripAdvance(String id) => '$transport/trips/$id/advance/';
  static String tripClose(String id) => '$transport/trips/$id/close/';
  static String tripReopen(String id) => '$transport/trips/$id/reopen/';
  static String tripLink(String id) => '$transport/trips/$id/link/';
  static String tripLoad(String id) => '$transport/trips/$id/load/';

  static const String customers = '$transport/customers/';
  static const String vehicles = '$transport/vehicles/';
  static const String drivers = '$transport/drivers/';
  static const String routes = '$transport/routes/';
  static const String payments = '$transport/payments/';
  static const String expenses = '$transport/expenses/';
}
