import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/envelope.dart';
import '../../domain/entities/example_item.dart';

class ExampleItemsApi {
  const ExampleItemsApi(this._client);

  final ApiClient _client;

  Future<List<ExampleItem>> list({String query = ''}) async {
    final response = await _client.getList(
      ApiEndpoints.exampleItems,
      query: query.trim().isEmpty ? null : <String, dynamic>{'q': query.trim()},
    );
    return response
        .map((value) => ExampleItem.fromJson(Envelope.asMap(value)))
        .toList(growable: false);
  }

  Future<ExampleItem> create({
    required String name,
    required String code,
    required String description,
    required int quantity,
  }) async {
    final response = await _client.postMap(
      ApiEndpoints.exampleItemCreate,
      body: _payload(
        name: name,
        code: code,
        description: description,
        quantity: quantity,
      ),
    );
    return ExampleItem.fromJson(response);
  }

  Future<ExampleItem> update(
    int id, {
    required String name,
    required String code,
    required String description,
    required int quantity,
  }) async {
    final response = await _client.patchMap(
      ApiEndpoints.exampleItemUpdate(id),
      body: _payload(
        name: name,
        code: code,
        description: description,
        quantity: quantity,
      ),
    );
    return ExampleItem.fromJson(response);
  }

  Future<void> delete(int id) =>
      _client.deleteVoid(ApiEndpoints.exampleItemDelete(id));

  Map<String, Object> _payload({
    required String name,
    required String code,
    required String description,
    required int quantity,
  }) => <String, Object>{
        'name': name.trim(),
        'code': code.trim(),
        'description': description.trim(),
        'quantity': quantity,
      };
}
