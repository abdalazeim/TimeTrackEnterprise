import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/sync/sync_overview.dart';

/// ملخص الطابور وآخر مزامنة لشاشة الرئيسية.
final syncOverviewProvider = FutureProvider<SyncOverview>((ref) async {
  final state = await ref.watch(syncStateDaoProvider).ensure();
  final counts = await ref.watch(syncQueueProvider).counts();
  final cachedRecords = await ref.watch(syncRecordsDaoProvider).totalCount();
  return SyncOverview.from(
    counts: counts,
    state: state,
    cachedRecords: cachedRecords,
  );
});
