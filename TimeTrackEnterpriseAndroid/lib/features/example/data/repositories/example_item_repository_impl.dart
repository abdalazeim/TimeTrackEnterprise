import '../../domain/entities/example_item.dart';
import '../../domain/repositories/example_item_repository.dart';
import '../datasources/example_items_api.dart';

class ExampleItemRepositoryImpl implements ExampleItemRepository {
  const ExampleItemRepositoryImpl(this._api);

  final ExampleItemsApi _api;

  @override
  Future<List<ExampleItem>> list({String query = ''}) =>
      _api.list(query: query);

  @override
  Future<ExampleItem> create({
    required String name,
    required String code,
    required String description,
    required int quantity,
  }) =>
      _api.create(
        name: name,
        code: code,
        description: description,
        quantity: quantity,
      );

  @override
  Future<ExampleItem> update(
    int id, {
    required String name,
    required String code,
    required String description,
    required int quantity,
  }) =>
      _api.update(
        id,
        name: name,
        code: code,
        description: description,
        quantity: quantity,
      );

  @override
  Future<void> delete(int id) => _api.delete(id);
}
