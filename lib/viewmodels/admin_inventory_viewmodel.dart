import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/pharma_service.dart';

/// ViewModel de las acciones de inventario del administrador (RF-19).
///
/// La vista solo captura los datos; la validación y la escritura viven en el
/// servicio. Después de cada cambio se refresca el dashboard.
class AdminInventoryViewModel extends ChangeNotifier {
  AdminInventoryViewModel({PharmaService? service, this.onChanged})
    : _service = service ?? PharmaService.instance;

  final PharmaService _service;
  final Future<void> Function()? onChanged;

  bool _saving = false;
  String? _error;

  bool get saving => _saving;

  String? get error => _error;

  Future<bool> createProduct({
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
    return _run(
      () => _service.createProduct(
        name: name,
        brand: brand,
        presentation: presentation,
        category: category,
        price: price,
        stock: stock,
        description: description,
        unitOfMeasure: unitOfMeasure,
        requiresExpiry: requiresExpiry,
      ),
    );
  }

  Future<bool> updatePrice(String productId, double price) async {
    return _run(() => _service.updateProductPrice(productId, price));
  }

  Future<bool> registerEntry(
    String productId,
    int quantity, {
    String lotCode = '',
    DateTime? expiresAt,
  }) async {
    return _run(
      () => _service.registerStockEntry(
        productId,
        quantity,
        lotCode: lotCode,
        expiresAt: expiresAt,
      ),
    );
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<String?> Function() action) async {
    _saving = true;
    _error = null;
    notifyListeners();

    final error = await action();
    _saving = false;
    _error = error;
    notifyListeners();

    if (error == null) await onChanged?.call();
    return error == null;
  }
}
