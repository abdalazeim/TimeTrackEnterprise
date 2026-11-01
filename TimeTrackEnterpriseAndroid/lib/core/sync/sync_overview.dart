import '../database/dao/sync_state_dao.dart';
import 'pending_operation.dart';

/// ملخص حالة المزامنة/الطابور لعرضه في الواجهة.
class SyncOverview {
  const SyncOverview({
    required this.counts,
    required this.deviceId,
    this.lastSyncAt,
    this.lastStatus,
    this.cachedRecords = 0,
  });

  final Map<OperationStatus, int> counts;
  final String deviceId;
  final DateTime? lastSyncAt;
  final String? lastStatus;

  /// عدد الصفوف المحلية القابلة للقراءة دون اتصال.
  final int cachedRecords;

  int countOf(OperationStatus status) => counts[status] ?? 0;

  int get waiting => countOf(OperationStatus.pending);

  int get inFlight => countOf(OperationStatus.sent);

  int get retrying => countOf(OperationStatus.failed);

  int get needsAttention =>
      countOf(OperationStatus.rejected) + countOf(OperationStatus.dead);

  int get applied => countOf(OperationStatus.applied);

  int get total => counts.values.fold(0, (sum, value) => sum + value);

  bool get hasQueuedWork => waiting + inFlight + retrying + needsAttention > 0;

  factory SyncOverview.from({
    required Map<OperationStatus, int> counts,
    required SyncState state,
    int cachedRecords = 0,
  }) {
    return SyncOverview(
      counts: counts,
      deviceId: state.deviceId,
      lastSyncAt: state.lastSyncAt,
      lastStatus: state.lastStatus,
      cachedRecords: cachedRecords,
    );
  }
}
