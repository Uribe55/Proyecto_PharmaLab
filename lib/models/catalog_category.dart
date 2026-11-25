import 'product.dart';

/// Categoría cuyo nombre e identificador proceden de Firestore.
class CatalogCategory {
  const CatalogCategory({required this.id, required this.name});

  final String id;
  final String name;

  /// La categoría visual no reemplaza el identificador real de Firestore.
  ProductCategory get visualCategory {
    final lower = name.toLowerCase();
    if (lower.contains('quimica') ||
        lower.contains('química') ||
        lower.contains('sanguin')) {
      return ProductCategory.reactivosQuimicaSanguinea;
    }
    if (lower.contains('inmuno') || lower.contains('serolog')) {
      return ProductCategory.reactivosInmunologia;
    }
    if (lower.contains('equipo') ||
        lower.contains('instrument') ||
        lower.contains('analizador')) {
      return ProductCategory.equiposLaboratorio;
    }
    return ProductCategory.insumosClinicos;
  }
}
