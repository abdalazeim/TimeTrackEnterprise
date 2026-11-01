/// Route names and paths owned by the optional transport example.
class TransportRoutes {
  const TransportRoutes._();

  static const String shipments = '/transport/shipments';
  static const String shipmentNew = '$shipments/new';
  static const String receiving = '/transport/receiving';
  static const String goods = '/transport/goods';
  static const String trips = '/transport/trips';
  static const String tripNew = '$trips/new';
  static const String reports = '/transport/reports';

  static String shipment(String id) => '$shipments/$id';
  static String shipmentEdit(String id) => '${shipment(id)}/edit';
  static String trip(String id) => '$trips/$id';
  static String tripEdit(String id) => '${trip(id)}/edit';
}
