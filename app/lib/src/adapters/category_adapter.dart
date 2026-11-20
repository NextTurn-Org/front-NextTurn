import '../models/category.dart';
import 'http/api_client.dart';

/// Port: what the services need, independent of where data comes from.
abstract interface class CategoryAdapter {
  Future<List<Category>> fetchAll();
  Future<Category> create(String name);
}

/// Adapter for the Symfony `CategoryController` (`/api/categories`).
///
/// Converts the API JSON (CategoryDto) into the domain [Category].
class HttpCategoryAdapter implements CategoryAdapter {
  HttpCategoryAdapter(this._client);

  final ApiClient _client;
  static const _path = '/api/categories';

  @override
  Future<List<Category>> fetchAll() async {
    final json = await _client.get(_path) as List<dynamic>;
    return json.cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  @override
  Future<Category> create(String name) async {
    final json = await _client.post(_path, {'name': name});
    return _fromJson(json as Map<String, dynamic>);
  }

  static Category _fromJson(Map<String, dynamic> json) =>
      Category(id: json['id'] as String, name: json['name'] as String);
}
