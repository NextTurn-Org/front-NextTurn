import 'package:material_ui/material_ui.dart';

import '../../models/category.dart';

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.label_outline),
      title: Text(category.name),
    );
  }
}
