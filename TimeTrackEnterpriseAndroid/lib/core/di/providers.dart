import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/datasources/auth_api.dart';
import '../config/app_config.dart';
import '../auth/profile_store.dart';
import '../auth/session_manager.dart';
import '../auth/token_store.dart';
import '../database/app_database.dart';
import '../database/dao/sync_log_dao.dart';
import '../database/dao/sync_records_dao.dart';
import '../database/dao/sync_state_dao.dart';
import '../network/api_client.dart';
import '../network/api_interceptor.dart';
import '../network/dio_factory.dart';
import '../sync/sync_queue.dart';
import '../sync/sync_coordinator.dart';

/// عميل HTTP واحد لكل التطبيق.
final dioProvider = Provider<Dio>((ref) {
  final dio = createDio();
  ref.onDispose(dio.close);
  return dio;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final profileStoreProvider = Provider<ProfileStore>(
  (ref) => SecureProfileStore(),
);

/// مالك الجلسة. يُركّب الـInterceptor على Dio قبل أي طلب.
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final dio = ref.watch(dioProvider);
  final authApi = AuthApi(ApiClient(dio));
  final session = SessionManager(
    store: ref.watch(tokenStoreProvider),
    refreshTokens: authApi.refresh,
  );
  dio.interceptors.add(ApiInterceptor(session: session, dio: dio));
  ref.onDispose(session.dispose);
  return session;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // يضمن تركيب Interceptor المصادقة قبل أول استدعاء.
  ref.watch(sessionManagerProvider);
  return ApiClient(ref.watch(dioProvider));
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final session = ref.watch(sessionManagerProvider);
  final database = AppDatabase(
    scopeKey: () => '${AppConfig.baseUrl}|${session.tokens?.userId ?? 'guest'}',
  );
  ref.onDispose(database.close);
  return database;
});

final syncStateDaoProvider = Provider<SyncStateDao>(
  (ref) => SyncStateDao(ref.watch(appDatabaseProvider)),
);

final syncRecordsDaoProvider = Provider<SyncRecordsDao>(
  (ref) => SyncRecordsDao(ref.watch(appDatabaseProvider)),
);

final syncLogDaoProvider = Provider<SyncLogDao>(
  (ref) => SyncLogDao(ref.watch(appDatabaseProvider)),
);

final syncQueueProvider = Provider<SyncQueue>(
  (ref) => SyncQueue(ref.watch(appDatabaseProvider)),
);

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final session = ref.watch(sessionManagerProvider);
  return SyncCoordinator(
    client: ref.watch(apiClientProvider),
    queue: ref.watch(syncQueueProvider),
    state: ref.watch(syncStateDaoProvider),
    records: ref.watch(syncRecordsDaoProvider),
    log: ref.watch(syncLogDaoProvider),
    models: AppConfig.syncModelNames,
    identity: () {
      final tokens = session.tokens;
      if (tokens == null || !tokens.isValid || tokens.userId == null) {
        return null;
      }
      return '${tokens.server ?? AppConfig.baseUrl}|${tokens.userId}';
    },
  );
});
