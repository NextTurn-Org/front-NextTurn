/// Domain model used by services and components.
///
/// It knows nothing about JSON or HTTP: adapters convert API data into it.
class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Category && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
