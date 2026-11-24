import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/product.dart';

void main() {
  test('La cantidad representa cajas, no tabletas individuales', () {
    final product = Product(
      id: 'PROD001',
      name: 'Paracetamol',
      brand: '',
      presentation: 'Caja de 2 blísteres de 10 tabletas',
      category: ProductCategory.genericos,
      price: 150,
      stock: 100,
      unitOfMeasure: 'Caja',
      unitsPerPackage: 20,
    );

    expect(product.saleUnit, 'caja');
    expect(product.quantityLabel(1), '1 caja');
    expect(product.quantityLabel(3), '3 cajas');
    expect(product.estimatedTotal(3), 450);
    expect(product.unitsPerPackage, 20);
    expect(product.stock, 100); // Calcular no descuenta existencias.
  });

  test('Las existencias de guantes se interpretan en cajas', () {
    final product = Product(
      id: 'PROD002',
      name: 'Guantes de nitrilo',
      brand: '',
      presentation: 'Caja de 100 unidades',
      category: ProductCategory.insumos,
      price: 85,
      stock: 50,
      unitOfMeasure: 'Caja',
      unitsPerPackage: 100,
    );

    expect(product.quantityLabel(product.stock), '50 cajas');
    expect(product.estimatedTotal(2), 170);
    expect(product.stock, 50);
  });
}
