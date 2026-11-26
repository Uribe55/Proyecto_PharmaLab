/// Categorías definidas en el RF-02 y el RF-03 del proyecto.
///
/// PharmaLab distribuye reactivos, equipos e insumos de laboratorio; por eso
/// el catálogo ya no se organiza con categorías de farmacia minorista.
enum ProductCategory {
  reactivosQuimicaSanguinea('Reactivos de Química Sanguínea'),
  reactivosInmunologia('Reactivos de Inmunología'),
  equiposLaboratorio('Equipos de Laboratorio'),
  insumosClinicos('Insumos Clínicos');

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
    this.categoryId = '',
    this.categoryName = '',
    this.code = '',
    this.concentration = '',
    this.material = '',
    this.size = '',
    this.requiresExpiry = false,
    this.unitOfMeasure = '',
    this.unitsPerPackage = 0,
  });

  final String id;
  final String name;
  final String brand;
  final String presentation;
  final ProductCategory category;
  final double price;
  final String description;
  final bool isFeatured;
  final String categoryId;
  final String categoryName;
  final String code;
  final String concentration;
  final String material;
  final String size;
  final bool requiresExpiry;
  /// Unidad comercial: Caja, Frasco, Paquete...
  final String unitOfMeasure;
  /// Contenido de la presentacion, NO unidades de stock.
  final int unitsPerPackage;

  String get displayCategory => categoryName.isEmpty ? category.label : categoryName;

  /// El stock es mutable: se descuenta al confirmar un pedido (RF-08).
  int stock;

  /// Copia inmutable usada por el administrador al actualizar precios (RF-19).
  Product copyWith({
    String? id,
    String? name,
    String? brand,
    String? presentation,
    ProductCategory? category,
    double? price,
    int? stock,
    String? description,
    bool? isFeatured,
    String? categoryId,
    String? categoryName,
    String? code,
    String? concentration,
    String? material,
    String? size,
    bool? requiresExpiry,
    String? unitOfMeasure,
    int? unitsPerPackage,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      presentation: presentation ?? this.presentation,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      code: code ?? this.code,
      concentration: concentration ?? this.concentration,
      material: material ?? this.material,
      size: size ?? this.size,
      requiresExpiry: requiresExpiry ?? this.requiresExpiry,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      unitsPerPackage: unitsPerPackage ?? this.unitsPerPackage,
    );
  }

  /// Identifica qué se selecciona y qué se descuenta del inventario.
  String get saleUnit {
    final configured = unitOfMeasure.trim().toLowerCase();
    if (configured.isNotEmpty) return configured;

    // Compatibilidad con productos locales anteriores que no tienen unidad.
    final presentationText = presentation.trim().toLowerCase();
    if (presentationText.startsWith('caja')) return 'caja';
    if (presentationText.startsWith('frasco')) return 'frasco';
    if (presentationText.startsWith('paquete')) return 'paquete';
    if (presentationText.startsWith('blíster') ||
        presentationText.startsWith('blister')) {
      return 'blíster';
    }
    return 'unidad';
  }

  String unitForQuantity(int quantity) {
    final singular = saleUnit;
    if (quantity == 1) return singular;
    if (singular == 'blíster' || singular == 'blister') return 'blísteres';
    if (singular == 'unidad') return 'unidades';
    if (singular.endsWith('s')) return singular;
    if (singular.endsWith('z')) {
      return '${singular.substring(0, singular.length - 1)}ces';
    }
    return '${singular}s';
  }

  String quantityLabel(int quantity) => '$quantity ${unitForQuantity(quantity)}';

  /// Solo una simulacion informativa; no realiza ninguna escritura.
  double estimatedTotal(int quantity) => price * quantity;

  bool get isAvailable => stock > 0;

  bool get isLowStock => stock > 0 && stock <= 10;
}
