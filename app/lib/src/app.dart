import 'package:material_ui/material_ui.dart';

import 'adapters/category_adapter.dart';
import 'adapters/http/api_client.dart';
import 'components/category/categories_screen.dart';
import 'config/env.dart';
import 'services/category_service.dart';

/// Root widget. Wires adapters -> services -> components in one place.
class NextTurnApp extends StatefulWidget {
  const NextTurnApp({super.key, this.categoryAdapter});

  /// Inject a fake adapter in tests; defaults to the HTTP one.
  final CategoryAdapter? categoryAdapter;

  @override
  State<NextTurnApp> createState() => _NextTurnAppState();
}

class _NextTurnAppState extends State<NextTurnApp> {
  final _apiClient = ApiClient(baseUrl: Env.apiUrl);
  late final _categoryService = CategoryService(
    widget.categoryAdapter ?? HttpCategoryAdapter(_apiClient),
  );

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextTurn',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: CategoriesScreen(service: _categoryService),
    );
  }
}
