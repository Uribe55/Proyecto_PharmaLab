import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// Carrito de pedido compartido por las pantallas del cliente.
class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItem> _items = [];
  String? _ownerId;

  void bindSession(String? ownerId) {
    if (_ownerId == ownerId) return;
    _ownerId = ownerId;
    clear();
  }

  /// Actualiza datos sin cambiar silenciosamente las cantidades seleccionadas.
  void reconcile(List<Product> products) {
    final byId = {for (final product in products) product.cartKey: product};
    for (final item in _items) {
      final latest = byId[item.product.cartKey];
      item.availableInCatalog = latest != null;
      if (latest != null) {
        item.priceChanged =
            item.priceChanged || latest.price != item.product.price;
        item.product = latest;
      }
    }
    if (_items.isNotEmpty) notifyListeners();
  }

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get lineCount => _items.length;

  int get totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  int quantityFor(Product product) {
    for (final item in _items) {
      if (item.product.cartKey == product.cartKey) return item.quantity;
    }
    return 0;
  }

  /// Unidades que todavía pueden agregarse sin superar el stock (RF-09).
  int remainingFor(Product product) {
    final remaining = maximumFor(product) - quantityFor(product);
    return remaining < 0 ? 0 : remaining;
  }

  int maximumFor(Product product) {
    if (product.inventoryStock == null) return product.stock;
    final other = _items
        .where(
          (item) =>
              item.product.id == product.id &&
              item.product.cartKey != product.cartKey,
        )
        .fold(
          0,
          (sum, item) => sum + item.quantity * item.product.inventoryFactor,
        );
    final available = product.inventoryStock! - other;
    return available <= 0 ? 0 : available ~/ product.inventoryFactor;
  }

  bool get hasInventoryConflict =>
      _items.any((item) => item.quantity > maximumFor(item.product));

  /// Devuelve `false` si la cantidad solicitada supera el stock.
  bool add(Product product, {int quantity = 1}) {
    if (quantity <= 0 || product.stock <= 0) return false;

    final index = _items.indexWhere(
      (item) => item.product.cartKey == product.cartKey,
    );
    final current = index == -1 ? 0 : _items[index].quantity;

    if (current + quantity > maximumFor(product)) return false;

    if (index == -1) {
      _items.add(CartItem(product: product, quantity: quantity));
    } else {
      _items[index].product = product;
      _items[index].quantity += quantity;
    }

    notifyListeners();
    return true;
  }

  bool increment(Product product) => add(product);

  void decrement(Product product) {
    final index = _items.indexWhere(
      (item) => item.product.cartKey == product.cartKey,
    );
    if (index == -1) return;

    if (_items[index].quantity > 1) {
      _items[index].quantity -= 1;
    } else {
      _items.removeAt(index);
    }
    notifyListeners();
  }

  /// Ajusta la cantidad de una línea respetando el stock disponible.
  void setQuantity(Product product, int quantity) {
    final index = _items.indexWhere(
      (item) => item.product.cartKey == product.cartKey,
    );
    if (index == -1) return;

    if (quantity <= 0 || product.stock <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return;
    }

    final maximum = maximumFor(product);
    if (maximum < 1) return;
    final capped = quantity > maximum ? maximum : quantity;
    if (_items[index].quantity == capped) return;

    _items[index].quantity = capped;
    notifyListeners();
  }

  void remove(Product product) {
    final before = _items.length;
    _items.removeWhere((item) => item.product.cartKey == product.cartKey);
    if (_items.length != before) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
