import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/datasources/example_items_api.dart';
import '../../data/repositories/example_item_repository_impl.dart';
import '../../domain/entities/example_item.dart';
import '../../domain/repositories/example_item_repository.dart';

final exampleItemsApiProvider = Provider<ExampleItemsApi>(
  (ref) => ExampleItemsApi(ref.watch(apiClientProvider)),
);

final exampleItemRepositoryProvider = Provider<ExampleItemRepository>(
  (ref) => ExampleItemRepositoryImpl(ref.watch(exampleItemsApiProvider)),
);

final exampleItemsProvider = FutureProvider.family<List<ExampleItem>, String>(
  (ref, query) => ref.watch(exampleItemRepositoryProvider).list(query: query),
);
