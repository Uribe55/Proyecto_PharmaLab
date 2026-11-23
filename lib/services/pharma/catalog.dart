part of '../pharma_service.dart';

/// Consultas del catálogo local de demostración.
mixin _PharmaCatalog on _PharmaServiceState {
  List<Product> get products => List.unmodifiable(_products);

  List<Product> get featuredProducts =>
      _products.where((product) => product.isFeatured).toList();

  int get productsInStock =>
      _products.where((product) => product.isAvailable).length;

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
