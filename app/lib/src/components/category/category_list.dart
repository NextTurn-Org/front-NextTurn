import 'package:material_ui/material_ui.dart';

import '../../models/category.dart';
import 'category_tile.dart';

class CategoryList extends StatelessWidget {
  const CategoryList({super.key, required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('No categories yet'));
    }
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (_, i) => CategoryTile(category: categories[i]),
    );
  }
}
