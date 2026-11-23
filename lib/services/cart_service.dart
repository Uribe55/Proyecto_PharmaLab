import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// Carrito de pedido compartido por las pantallas del cliente.
class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get lineCount => _items.length;

  int get totalUnits =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  int quantityFor(Product product) {
    for (final item in _items) {
      if (item.product.id == product.id) return item.quantity;
    }
    return 0;
  }

  /// Unidades que todavía pueden agregarse sin superar el stock (RF-09).
  int remainingFor(Product product) {
    final remaining = product.stock - quantityFor(product);
    return remaining < 0 ? 0 : remaining;
  }

  /// Devuelve `false` si la cantidad solicitada supera el stock.
  bool add(Product product, {int quantity = 1}) {
    if (quantity <= 0 || product.stock <= 0) return false;

    final index = _items.indexWhere((item) => item.product.id == product.id);
    final current = index == -1 ? 0 : _items[index].quantity;

    if (current + quantity > product.stock) return false;

    if (index == -1) {
      _items.add(CartItem(product: product, quantity: quantity));
    } else {
      _items[index].quantity += quantity;
    }

    notifyListeners();
    return true;
  }

  bool increment(Product product) => add(product);

  void decrement(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
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
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index == -1) return;

    if (quantity <= 0 || product.stock <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return;
    }

    final capped = quantity > product.stock ? product.stock : quantity;
    if (_items[index].quantity == capped) return;

    _items[index].quantity = capped;
    notifyListeners();
  }

  void remove(Product product) {
    final before = _items.length;
    _items.removeWhere((item) => item.product.id == product.id);
    if (_items.length != before) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
