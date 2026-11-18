/// Categorías definidas en el RF-02 del proyecto.
enum ProductCategory {
  genericos('Genéricos'),
  insumos('Insumos'),
  vitaminas('Vitaminas');

  const ProductCategory(this.label);

  final String label;
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.presentation,
    required this.category,
    required this.price,
    required this.stock,
    this.description = '',
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final String brand;
  final String presentation;
  final ProductCategory category;
  final double price;
  final String description;
  final bool isFeatured;

  /// El stock es mutable: se descuenta al confirmar un pedido (RF-08).
  int stock;

  bool get isAvailable => stock > 0;

  bool get isLowStock => stock > 0 && stock <= 10;
}
