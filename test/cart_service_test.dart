import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/product.dart';
import 'package:proyecto_final_movil/services/cart_service.dart';

void main() {
  final cart = CartService.instance;
  setUp(cart.clear);
  tearDown(cart.clear);

  test('Actualizar un producto agotado elimina la línea del carrito', () {
    final product = Product(
      id: 'agotado',
      name: 'Producto',
      brand: '',
      presentation: 'Caja',
      category: ProductCategory.insumos,
      price: 10,
      stock: 2,
    );
    expect(cart.add(product, quantity: 2), isTrue);
    product.stock = 0;

    cart.setQuantity(product, 1);

    expect(cart.isEmpty, isTrue);
    expect(cart.subtotal, 0);
  });
}
