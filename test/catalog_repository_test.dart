import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/catalog_repository.dart';
import 'package:proyecto_final_movil/models/catalog_category.dart';
import 'package:proyecto_final_movil/models/product_batch.dart';

void main() {
  test('El catálogo calcula stock por lotes sin incluir vencidos', () {
    final repository = CatalogRepository();
    const products = [
      CatalogProductRecord(
        id: 'PROD001', name: 'Paracetamol', code: 'MED-001', brand: '',
        description: '', presentation: 'Caja de 20 tabletas',
        categoryId: 'CAT001', price: 150, requiresExpiry: true,
        concentration: '500 mg', material: '', size: '', featured: false,
      ),
      CatalogProductRecord(
        id: 'PROD002', name: 'Guantes de nitrilo', code: 'INS-001',
        brand: '', description: '', presentation: 'Caja de 100 unidades',
        categoryId: 'CAT002', price: 85, requiresExpiry: false,
        concentration: '', material: 'Nitrilo', size: 'M', featured: false,
      ),
    ];
    const categories = [
      CatalogCategory(id: 'CAT001', name: 'Medicamentos'),
      CatalogCategory(id: 'CAT002', name: 'Insumos'),
    ];
    final lots = [
      ProductBatch(id: 'LOTE001', productId: 'PROD001', available: 100,
          expiresAt: DateTime(2027, 6, 30)),
      ProductBatch(id: 'LOTE003', productId: 'PROD001', available: 20,
          expiresAt: DateTime(2026, 10, 1)),
      const ProductBatch(id: 'LOTE002', productId: 'PROD002', available: 50),
    ];

    final result = repository.assemble(
      records: products, categories: categories, batches: lots,
      now: DateTime(2026, 11, 22),
    );

    final paracetamol = result.firstWhere((item) => item.id == 'PROD001');
    final guantes = result.firstWhere((item) => item.id == 'PROD002');
    expect(paracetamol.stock, 100);
    expect(paracetamol.displayCategory, 'Medicamentos');
    expect(paracetamol.concentration, '500 mg');
    expect(guantes.stock, 50);
    expect(guantes.material, 'Nitrilo');
  });

  test('Un medicamento sin vencimiento registrado no suma stock', () {
    final repository = CatalogRepository();
    const item = CatalogProductRecord(
      id: 'PROD001', name: 'Paracetamol', code: '', brand: '',
      description: '', presentation: 'Caja', categoryId: 'CAT001',
      price: 150, requiresExpiry: true, concentration: '',
      material: '', size: '', featured: false,
    );
    final result = repository.assemble(
      records: [item],
      categories: const [CatalogCategory(id: 'CAT001', name: 'Medicamentos')],
      batches: const [ProductBatch(
        id: 'LOTE001', productId: 'PROD001', available: 50,
      )],
      now: DateTime(2026, 11, 22),
    );
    expect(result.single.stock, 0);
  });
}
