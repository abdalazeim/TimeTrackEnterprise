import '../../../../core/database/dao/sync_records_dao.dart';

/// تخزين قوائم النقل محليًا للقراءة دون اتصال.
class TransportCache {
  TransportCache(this._dao);

  final SyncRecordsDao _dao;

  static const String shipments = 'shipment';
  static const String goods = 'goods';
  static const String trips = 'trip';
  static const String customers = 'customer';
  static const String vehicles = 'vehicle';
  static const String drivers = 'driver';
  static const String routes = 'route';
  static const String payments = 'payment';
  static const String expenses = 'expense';

  Future<List<Map<String, dynamic>>> read(String model) async {
    try {
      final records = await _dao.page(model, limit: 2000);
      return records
          .map((record) => record.payload)
          .where((payload) => payload.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> write(String model, List<Map<String, dynamic>> rows) async {
    try {
      await _dao.replaceAll(model, rows);
    } catch (_) {
      // التخزين المحلي تحسين لا شرط؛ فشله لا يُفشل القراءة من الخادم.
    }
  }
}
