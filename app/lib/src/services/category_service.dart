import '../adapters/category_adapter.dart';
import '../models/category.dart';

/// Business rules for categories. Depends on the [CategoryAdapter] port,
/// never on HTTP directly, so it can be tested with a fake adapter.
class CategoryService {
  CategoryService(this._adapter);

  final CategoryAdapter _adapter;

  /// Same limit as the back (`Assert\Length(max: 255)`).
  static const maxNameLength = 255;

  Future<List<Category>> getCategories() async {
    final categories = await _adapter.fetchAll();
    return [...categories]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<Category> addCategory(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (trimmed.length > maxNameLength) {
      throw ArgumentError.value(name, 'name', 'max $maxNameLength characters');
    }
    return _adapter.create(trimmed);
  }
}
