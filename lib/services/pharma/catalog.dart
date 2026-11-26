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

  /// RF-19: alta de producto desde el inventario administrativo.
  Future<String?> createProduct({
    required String name,
    required String brand,
    required String presentation,
    required ProductCategory category,
    required double price,
    required int stock,
    String description = '',
    String unitOfMeasure = 'Unidad',
    bool requiresExpiry = false,
  }) async {
    if (!_isAdmin) return 'Solo un administrador puede dar de alta productos.';
    if (name.trim().isEmpty) return 'Ingresa el nombre del producto.';
    if (presentation.trim().isEmpty) return 'Ingresa la presentación.';
    if (price <= 0) return 'El precio debe ser mayor que cero.';
    if (stock < 0) return 'El stock inicial no puede ser negativo.';

    if (!usesFirebase) {
      final product = Product(
        id: 'p-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        brand: brand.trim(),
        presentation: presentation.trim(),
        category: category,
        price: price,
        stock: stock,
        description: description.trim(),
        unitOfMeasure: unitOfMeasure.trim(),
        requiresExpiry: requiresExpiry,
      );
      _products.insert(0, product);
      notifyListeners();
      return null;
    }

    try {
      final categoryId = await _resolveCategoryId(category);
      final reference = await _db.collection('productos').add({
        'nombre': name.trim(),
        'codigo': '',
        'marca': brand.trim(),
        'descripcion': description.trim(),
        'presentacion': presentation.trim(),
        'categoria_id': categoryId,
        'categoria': category.label,
        'precio': price,
        'stock': stock,
        'requiere_vencimiento': requiresExpiry,
        'destacado': false,
        'unidadMedida': unitOfMeasure.trim(),
        'unidad_por_envase': 1,
        'estado': true,
      });
      if (stock > 0) {
        await _db.collection('lotes_productos').add({
          'producto_id': reference.id,
          'producto_nombre': name.trim(),
          'codigo_lote': 'INICIAL',
          'cantidad_disponible': stock,
          'fecha_vencimiento': null,
          'estado': true,
        });
      }
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return _firestoreWriteError(e, 'el alta del producto');
    } catch (_) {
      return 'No se pudo dar de alta el producto.';
    }
  }

  /// RF-19: actualización del precio de venta.
  Future<String?> updateProductPrice(String productId, double price) async {
    if (!_isAdmin) return 'Solo un administrador puede cambiar precios.';
    if (price <= 0) return 'El precio debe ser mayor que cero.';

    final index = _products.indexWhere((product) => product.id == productId);
    if (index >= 0) {
      _products[index] = _products[index].copyWith(price: price);
      notifyListeners();
    }

    if (!usesFirebase) {
      return index >= 0 ? null : 'No encontramos el producto.';
    }
    try {
      await _db.collection('productos').doc(productId).update({
        'precio': price,
      });
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return _firestoreWriteError(e, 'la actualización del precio');
    } catch (_) {
      return 'No se pudo actualizar el precio.';
    }
  }

  /// RF-19: registro de ingreso de mercadería (aumento de stock).
  Future<String?> registerStockEntry(
    String productId,
    int quantity, {
    String lotCode = '',
    DateTime? expiresAt,
  }) async {
    if (!_isAdmin) return 'Solo un administrador puede registrar ingresos.';
    if (quantity <= 0) return 'La cantidad debe ser mayor que cero.';

    final index = _products.indexWhere((product) => product.id == productId);
    final product = index >= 0 ? _products[index] : null;
    if (!usesFirebase && product == null) {
      return 'No encontramos el producto.';
    }
    if (product != null) {
      _products[index] = product.copyWith(stock: product.stock + quantity);
      notifyListeners();
    }

    if (!usesFirebase) return null;

    try {
      await _db.collection('lotes_productos').add({
        'producto_id': productId,
        'producto_nombre': product?.name ?? '',
        'codigo_lote': lotCode.trim().isEmpty
            ? 'ING-${DateTime.now().millisecondsSinceEpoch}'
            : lotCode.trim(),
        'cantidad_disponible': quantity,
        'fecha_vencimiento': expiresAt == null
            ? null
            : Timestamp.fromDate(expiresAt),
        'estado': true,
      });
      await _db.collection('productos').doc(productId).update({
        'stock': FieldValue.increment(quantity),
      });
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return _firestoreWriteError(e, 'el ingreso de mercadería');
    } catch (_) {
      return 'No se pudo registrar el ingreso de mercadería.';
    }
  }

  bool get _isAdmin => _currentUser?.role == UserRole.administrador;

  Future<String> _resolveCategoryId(ProductCategory category) async {
    final match = await _db
        .collection('categorias')
        .where('nombre', isEqualTo: category.label)
        .limit(1)
        .get();
    if (match.docs.isNotEmpty) return match.docs.first.id;
    final created = await _db.collection('categorias').add({
      'nombre': category.label,
      'descripcion': category.label,
    });
    return created.id;
  }

  String _firestoreWriteError(FirebaseException e, String action) {
    if (e.code == 'permission-denied') {
      return 'Firestore denegó $action. Revisa las reglas de seguridad.';
    }
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      return 'No se pudo completar $action. Revisa tu conexión.';
    }
    return 'No se pudo completar $action (${e.code}).';
  }
}
