import 'product.dart';

/// Categoría cuyo nombre e identificador proceden de Firestore.
class CatalogCategory {
  const CatalogCategory({required this.id, required this.name});

  final String id;
  final String name;

  /// La categoría visual no reemplaza el identificador real de Firestore.
  ProductCategory get visualCategory {
    final lower = name.toLowerCase();
    if (lower.contains('insumo') || lower.contains('material')) {
      return ProductCategory.insumos;
    }
    if (lower.contains('vitamina') || lower.contains('suplemento')) {
      return ProductCategory.vitaminas;
    }
    return ProductCategory.genericos;
  }
}
