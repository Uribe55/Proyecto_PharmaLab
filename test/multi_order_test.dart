import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/models/product.dart';
import 'package:proyecto_final_movil/models/cart_item.dart';
import 'package:proyecto_final_movil/services/cart_service.dart';
import 'package:proyecto_final_movil/data/repositories/remote_order_repository.dart';
import 'package:proyecto_final_movil/data/mappers/firestore_order_mapper.dart';
import 'package:proyecto_final_movil/viewmodels/checkout_view_model.dart';

import 'checkout_view_model_test.dart' as fixtures;

import 'package:proyecto_final_movil/data/repositories/catalog_repository.dart';
import 'package:proyecto_final_movil/models/product_batch.dart';
import 'package:proyecto_final_movil/services/dashboard_repository.dart';
import 'package:proyecto_final_movil/models/dashboard_metrics.dart';
import 'package:proyecto_final_movil/models/dashboard_models.dart';

class MultiRemote extends fixtures.FakeRemote implements MultiOrderCapability {
  @override
  bool get supportsMultipleProducts => true;
}

Product variant(String id, int factor, double price, {int baseStock = 100}) =>
    Product(
      id: 'PROD001',
      name: 'Producto',
      brand: '',
      presentation: id,
      category: ProductCategory.insumosClinicos,
      price: price,
      stock: baseStock ~/ factor,
      presentationId: id,
      inventoryFactor: factor,
      inventoryStock: baseStock,
    );

void main() {
  test('administrador cuenta un pedido con tres productos una sola vez y conserva categorías históricas', () {
    final order = DashboardRepository().mapOrder('multi', {
      'schema_version': 'transactional_multi_v1',
      'numero_comercial': 'PED004',
      'estado': 'entregado',
      'total': 6800,
      'fecha_pedido': Timestamp.fromDate(DateTime.utc(2026, 11, 27, 12)),
      'fecha_logistica': Timestamp.fromDate(DateTime.utc(2026, 11, 27, 15)),
      'lineas': [
        {
          'id_producto': 'A',
          'nombre': 'A',
          'cantidad': 45,
          'precio_unitario': 150,
          'categoria': 'Medicamentos',
        },
        {
          'id_producto': 'B',
          'nombre': 'B',
          'cantidad': 20,
          'precio_unitario': 2,
          'categoria': 'Insumos',
        },
        {
          'id_producto': 'C',
          'nombre': 'C',
          'cantidad': 5,
          'precio_unitario': 2,
          'categoria': 'Reactivos',
        },
      ],
    });
    final metrics = DashboardMetrics.compute(
      orders: [order],
      inventory: const DashboardInventory.loading(),
      period: DateRange.ofMonth(DateTime(2026, 11, 27, 12)),
      now: DateTime(2026, 11, 27, 12),
    );
    expect(metrics.totalInPeriod, 1);
    expect(metrics.salesMonth, 6800);
    expect(metrics.averageTicket, 6800);
    expect(metrics.topProducts.length, 3);
    expect(order.items.first.category, 'Medicamentos');
  });
  test('catálogo: variantes comparten lotes; excluye inactivos, fechas inválidas y vencidos', () {
    final result = CatalogRepository().assemble(
      records: const [
        CatalogProductRecord(
          id: 'P',
          name: 'P',
          code: '',
          brand: '',
          description: '',
          presentation: '',
          categoryId: '',
          price: 0,
          requiresExpiry: true,
          concentration: '',
          material: '',
          size: '',
          featured: false,
          baseInventory: true,
          presentations: [
            {
              'id': 'ten',
              'nombre': 'Blíster',
              'unidades_base': 10,
              'precio': 15,
              'estado': true,
            },
            {
              'id': 'twenty',
              'nombre': 'Caja',
              'unidades_base': 20,
              'precio': 28,
              'estado': true,
            },
          ],
        ),
      ],
      categories: [],
      batches: [
        ProductBatch(
          id: 'good',
          productId: 'P',
          available: 100,
          expiresAt: DateTime(2027),
        ),
        ProductBatch(
          id: 'inactive',
          productId: 'P',
          available: 100,
          active: false,
          expiresAt: DateTime(2027),
        ),
        ProductBatch(
          id: 'invalid',
          productId: 'P',
          available: 100,
          invalidExpiry: true,
        ),
        ProductBatch(
          id: 'expired',
          productId: 'P',
          available: 100,
          expiresAt: DateTime(2020),
        ),
      ],
      now: DateTime(2026, 11, 27),
    );
    expect(result.map((p) => p.stock), [10, 5]);
    expect(result.map((p) => p.inventoryStock), [100, 100]);
    expect(result.map((p) => p.cartKey).toSet().length, 2);
  });
  test(
    '3 blísteres y 2 cajas consumen 70 unidades del inventario compartido',
    () {
      final cart = CartService.instance;
      cart.clear();
      addTearDown(cart.clear);
      final blister = variant('blister', 10, 15), box = variant('caja', 20, 28);
      expect(cart.add(blister, quantity: 3), isTrue);
      expect(cart.add(box, quantity: 2), isTrue);
      expect(cart.items.length, 2);
      expect(cart.subtotal, 101);
      expect(cart.maximumFor(box), 3);
      expect(cart.remainingFor(box), 1);
      expect(cart.add(box, quantity: 2), isFalse);
      expect(cart.totalUnits, 5);
      cart.reconcile([
        variant('blister', 10, 15, baseStock: 60),
        variant('caja', 20, 28, baseStock: 60),
      ]);
      expect(cart.hasInventoryConflict, isTrue);
      expect(cart.items.map((i) => i.quantity), [
        3,
        2,
      ]); // Nunca reduce la compra silenciosamente.
    },
  );

  test('checkout múltiple envía todas las líneas bajo un solo ID', () async {
    final cart = fixtures.TestCart();
    cart.items.add(CartItem(product: variant('caja', 20, 28), quantity: 2));
    final remote = MultiRemote(), store = fixtures.MemoryStore();
    final vm = CheckoutViewModel(
      repository: remote,
      store: store,
      cart: cart,
      sessionUid: () => 'uid-a',
    );
    addTearDown(vm.dispose);
    addTearDown(cart.dispose);
    await vm.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(vm.scopeError, isNull);
    final order = await vm.confirm();
    expect(order, isNotNull);
    expect(remote.calls, 1);
    expect(remote.ids, 1);
    expect((remote.received!['items'] as List).length, 2);
    expect((remote.received!['items'] as List).last['presentationId'], 'caja');
    expect(cart.clears, 1);
  });

  test('checkout múltiple aplica el límite antes de persistir y conserva el carrito', () async {
    final cart = fixtures.TestCart();
    for (var i = 0; i < 20; i++) {
      cart.items.add(
        CartItem(product: cart.items.first.product.copyWith(id: 'P$i')),
      );
    }
    final remote = MultiRemote();
    final vm = CheckoutViewModel(
      repository: remote,
      store: fixtures.MemoryStore(),
      cart: cart,
      sessionUid: () => 'uid-a',
    );
    addTearDown(vm.dispose);
    addTearDown(cart.dispose);
    await vm.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(vm.scopeError, isNotNull);
    expect(await vm.confirm(), isNull);
    expect(remote.calls, 0);
    expect(cart.clears, 0);
  });

  test('mapper conserva tres productos, cuatro lotes, conversiones y precio histórico', () {
    final order = FirestoreOrderMapper.fromMaps(
      documentId: 'internal',
      ownerUid: 'uid-a',
      data: {
        'schema_version': 'transactional_multi_v1',
        'numero_comercial': 'PED003',
        'estado': 'pendiente',
        'fecha_pedido': Timestamp.now(),
        'id_cliente': 'FARM001',
        'total': 6800,
        'nombre_farmacia': 'Farmacia',
      },
      details: [
        {
          'id_producto': 'A',
          'nombre': 'A histórico',
          'cantidad': 45,
          'precio_unitario': 150,
          'factor_inventario': 1,
          'cantidad_inventario': 45,
          'asignaciones_lotes': [
            {'id_lote': 'L1', 'cantidad': 30},
            {'id_lote': 'L2', 'cantidad': 15},
          ],
        },
        {
          'id_producto': 'B',
          'cantidad': 20,
          'precio_unitario': 2,
          'asignaciones_lotes': [
            {'id_lote': 'L3', 'cantidad': 20},
          ],
        },
        {
          'id_producto': 'C',
          'cantidad': 5,
          'precio_unitario': 2,
          'asignaciones_lotes': [
            {'id_lote': 'L4', 'cantidad': 5},
          ],
        },
      ],
      history: {},
    );
    expect(order.items.length, 3);
    expect(order.lotAllocations.length, 4);
    expect(order.items.first.name, 'A histórico');
    expect(order.total, 6800);
    expect(order.schemaVersion, 'transactional_multi_v1');
  });
}
