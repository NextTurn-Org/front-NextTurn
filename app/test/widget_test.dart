import 'package:app/src/adapters/category_adapter.dart';
import 'package:app/src/app.dart';
import 'package:app/src/models/category.dart';
import 'package:app/src/services/category_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCategoryAdapter implements CategoryAdapter {
  final items = <Category>[
    const Category(id: '2', name: 'Strategy'),
    const Category(id: '1', name: 'Board games'),
  ];

  @override
  Future<List<Category>> fetchAll() async => List.of(items);

  @override
  Future<Category> create(String name) async {
    final c = Category(id: '${items.length + 1}', name: name);
    items.add(c);
    return c;
  }
}

void main() {
  group('CategoryService', () {
    test('sorts categories by name', () async {
      final service = CategoryService(FakeCategoryAdapter());
      final names = (await service.getCategories()).map((c) => c.name);
      expect(names, ['Board games', 'Strategy']);
    });

    test('trims names and rejects empty ones', () async {
      final adapter = FakeCategoryAdapter();
      final service = CategoryService(adapter);
      await service.addCategory('  Party  ');
      expect(adapter.items.last.name, 'Party');
      expect(() => service.addCategory('   '), throwsArgumentError);
    });
  });

  testWidgets('shows categories from the adapter', (tester) async {
    await tester.pumpWidget(NextTurnApp(categoryAdapter: FakeCategoryAdapter()));
    await tester.pumpAndSettle();
    expect(find.text('Board games'), findsOneWidget);
    expect(find.text('Strategy'), findsOneWidget);
  });
}
