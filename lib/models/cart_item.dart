import 'product.dart';

class CartItem {
  CartItem({required this.product, this.quantity = 1});

  Product product;
  int quantity;
  bool availableInCatalog = true;
  bool priceChanged = false;
  bool get needsAdjustment => !availableInCatalog || quantity > product.stock;
  String? get issue => !availableInCatalog
      ? 'Producto no disponible en el catálogo.'
      : product.stock <= 0
      ? 'Producto sin stock. Elimínalo para continuar.'
      : quantity > product.stock
      ? 'Stock actualizado: ${product.quantityLabel(product.stock)}. Ajusta la cantidad.'
      : null;

  double get subtotal => product.price * quantity;
}
