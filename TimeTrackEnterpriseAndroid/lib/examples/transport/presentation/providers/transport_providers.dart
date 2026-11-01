import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/transport_api.dart';
import '../../data/local/transport_cache.dart';
import '../../data/repositories/transport_repository_impl.dart';
import '../../domain/entities/cached_data.dart';
import '../../domain/entities/goods_type.dart';
import '../../domain/entities/payment_expense.dart';
import '../../domain/entities/reference_entities.dart';
import '../../domain/entities/report_data.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/transport_repository.dart';

final transportCacheProvider = Provider<TransportCache>(
  (ref) => TransportCache(ref.watch(syncRecordsDaoProvider)),
);

final transportApiProvider = Provider<TransportApi>(
  (ref) => TransportApi(ref.watch(apiClientProvider)),
);

final transportRepositoryProvider = Provider<TransportRepository>(
  (ref) => TransportRepositoryImpl(
    api: ref.watch(transportApiProvider),
    cache: ref.watch(transportCacheProvider),
  ),
);

final transportMetaProvider = FutureProvider<TransportMeta>(
  (ref) => ref.watch(transportRepositoryProvider).meta(),
);

final shipmentsProvider = FutureProvider<CachedData<List<Shipment>>>(
  (ref) => ref.watch(transportRepositoryProvider).shipments(),
);

final goodsProvider = FutureProvider<CachedData<List<GoodsType>>>(
  (ref) => ref.watch(transportRepositoryProvider).goods(),
);

final tripsProvider = FutureProvider<CachedData<List<Trip>>>(
  (ref) => ref.watch(transportRepositoryProvider).trips(),
);

final customersProvider = FutureProvider<CachedData<List<Customer>>>(
  (ref) => ref.watch(transportRepositoryProvider).customers(),
);

final vehiclesProvider = FutureProvider<CachedData<List<Vehicle>>>(
  (ref) => ref.watch(transportRepositoryProvider).vehicles(),
);

final driversProvider = FutureProvider<CachedData<List<Driver>>>(
  (ref) => ref.watch(transportRepositoryProvider).drivers(),
);

final routesProvider = FutureProvider<CachedData<List<RouteInfo>>>(
  (ref) => ref.watch(transportRepositoryProvider).routes(),
);

final paymentsProvider = FutureProvider<CachedData<List<Payment>>>(
  (ref) => ref.watch(transportRepositoryProvider).payments(),
);

final expensesProvider = FutureProvider<CachedData<List<Expense>>>(
  (ref) => ref.watch(transportRepositoryProvider).expenses(),
);

/// تقرير محسوب من القوائم المثبتة في العقد الحقيقي.
///
/// لا نخترع شكل استجابة `/reports/` غير الموثق؛ نحسب المؤشرات نفسها التي
/// تحسبها واجهة الويب من الشحنات وسندات القبض والمصروفات.
final reportDataProvider =
    FutureProvider.family<CachedData<ReportData>, ReportPeriod>(
  (ref, period) async {
    final shipments = await ref.watch(shipmentsProvider.future);
    final payments = await ref.watch(paymentsProvider.future);
    final expenses = await ref.watch(expensesProvider.future);
    final meta = await ref.watch(transportMetaProvider.future);
    final now = DateTime.now();

    return CachedData<ReportData>(
      value: ReportData.build(
        shipments: shipments.value,
        payments: payments.value,
        expenses: expenses.value,
        start: period.startFrom(now),
        end: now,
        methods: meta.methods,
      ),
      fromCache:
          shipments.fromCache || payments.fromCache || expenses.fromCache,
    );
  },
);

/// يُبطل كل القوائم بعد أي تعديل على الخادم.
void invalidateTransportData(WidgetRef ref, {bool goods = true}) {
  ref.invalidate(shipmentsProvider);
  ref.invalidate(tripsProvider);
  ref.invalidate(paymentsProvider);
  ref.invalidate(expensesProvider);
  ref.invalidate(customersProvider);
  ref.invalidate(routesProvider);
  if (goods) ref.invalidate(goodsProvider);
}
