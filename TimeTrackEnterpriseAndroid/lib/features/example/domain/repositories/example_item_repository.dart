import '../entities/example_item.dart';

abstract interface class ExampleItemRepository {
  Future<List<ExampleItem>> list({String query = ''});

  Future<ExampleItem> create({
    required String name,
    required String code,
    required String description,
    required int quantity,
  });

  Future<ExampleItem> update(
    int id, {
    required String name,
    required String code,
    required String description,
    required int quantity,
  });

  Future<void> delete(int id);
}
