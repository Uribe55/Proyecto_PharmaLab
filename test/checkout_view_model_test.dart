import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto_final_movil/data/datasources/pending_checkout_store.dart';
import 'package:proyecto_final_movil/data/mappers/firestore_order_mapper.dart';
import 'package:proyecto_final_movil/data/repositories/remote_order_repository.dart';
import 'package:proyecto_final_movil/models/cart_item.dart';
import 'package:proyecto_final_movil/models/delivery_address.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/models/product.dart';
import 'package:proyecto_final_movil/viewmodels/cart_view_model.dart';
import 'package:proyecto_final_movil/viewmodels/checkout_view_model.dart';
import 'package:proyecto_final_movil/services/firebase_environment.dart';

class TestCart extends ChangeNotifier implements CartViewModel {
  @override
  final List<CartItem> items = [
    CartItem(
      product: Product(
        id: 'PROD001',
        name: 'Paracetamol',
        brand: '',
        presentation: 'Caja de 20 tabletas',
        category: ProductCategory.insumosClinicos,
        price: 150,
        stock: 15,
      ),
      quantity: 2,
    ),
  ];
  @override
  bool get canReview => items.isNotEmpty;
  int clears = 0;
  @override
  void clear() {
    items.clear();
    clears++;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryStore implements PendingCheckoutStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<Map<String, dynamic>?> read(String uid) async => values[uid] == null
      ? null
      : Map<String, dynamic>.from(jsonDecode(values[uid]!) as Map);
  @override
  Future<void> write(String uid, Map<String, dynamic>? value) async {
    if (fail) throw StateError('disk failure');
    if (value == null) {
      values.remove(uid);
    } else {
      values[uid] = jsonEncode(value);
    }
  }
}

class FakeRemote implements RemoteOrderRepository {
  @override
  bool confirmationEnabled = true;
  int calls = 0, lookups = 0, ids = 0;
  Object? failure;
  Completer<void>? delay;
  PharmacyOrder? committed;
  Map<String, dynamic>? received;
  PharmacyOrder order(String operationId, {bool cached = false}) =>
      PharmacyOrder(
        number: 'PL-2026-000001',
        documentId: 'ORD-test',
        operationId: operationId,
        createdAt: DateTime(2026, 11, 24),
        status: OrderStatus.pendiente,
        items: [],
        pharmacyName: 'Farmacia A',
        address: 'Av A',
        contactName: 'A',
        contactPhone: '',
        customerId: 'uid-a',
        remote: true,
        fromCache: cached,
      );
  @override
  String newOperationId() => 'operation-${++ids}';
  @override
  Future<PharmacyOrder> confirm(Map<String, dynamic> request) async {
    calls++;
    received = request;
    await delay?.future;
    if (failure != null) throw failure!;
    return committed ??= order(request['operationId'] as String);
  }

  @override
  Future<PharmacyOrder?> result(String operationId) async {
    lookups++;
    return committed;
  }

  @override
  Stream<List<DeliveryAddress>> watchAddresses() => Stream.value(const [
    DeliveryAddress(id: 'DIR001', name: 'Principal', address: 'Av A'),
  ]);
  @override
  Stream<List<PharmacyOrder>> watchOwnOrders() => const Stream.empty();
  @override
  Stream<PharmacyOrder> watchOrder(String documentId) => const Stream.empty();
  @override
  Future<void> addAddress(
    String name,
    String address,
    String reference,
  ) async {}
}

void main() {
  late TestCart cart;
  late MemoryStore store;
  late FakeRemote remote;
  late CheckoutViewModel vm;
  String? uid;
  CheckoutViewModel build() => CheckoutViewModel(
    repository: remote,
    store: store,
    cart: cart,
    sessionUid: () => uid,
  );
  setUp(() async {
    uid = 'uid-a';
    cart = TestCart();
    store = MemoryStore();
    remote = FakeRemote();
    vm = build();
    await vm.initialize();
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() {
    vm.dispose();
    cart.dispose();
  });

  test('doble pulsación envía una operación y vacía solo tras éxito', () async {
    remote.delay = Completer<void>();
    final first = vm.confirm();
    await Future<void>.delayed(Duration.zero);
    expect(await vm.confirm(), isNull);
    expect(remote.calls, 1);
    expect(cart.clears, 0);
    expect(store.values, isNotEmpty);
    remote.delay!.complete();
    expect(await first, isNotNull);
    expect(cart.clears, 1);
    expect(store.values, isEmpty);
  });
  test('rechazo no vacía carrito y precio cambiado exige otro clic', () async {
    remote.failure = const RemoteOrderException(
      'Precio cambió',
      definitive: true,
      prices: {'PROD001': 16000},
    );
    expect(await vm.confirm(), isNull);
    expect(cart.clears, 0);
    expect(vm.total, 320);
    expect(vm.hasPending, isFalse);
    expect(remote.calls, 1);
    remote.failure = null;
    await vm.confirm();
    expect(
      (remote.received!['items'] as List).single['expectedPriceCents'],
      16000,
    );
    expect(cart.clears, 1);
  });
  test(
    'timeout, reapertura y consulta recuperan el mismo pedido sin reenviar',
    () async {
      remote.failure = TimeoutException('Respuesta perdida');
      await vm.confirm();
      final operationId = vm.operationId!;
      expect(vm.uncertain, isTrue);
      expect(cart.clears, 0);
      remote.committed = remote.order(operationId);
      vm.dispose();
      vm = build();
      await vm.initialize();
      final order = await vm.confirm(consultOnly: true);
      expect(order!.operationId, operationId);
      expect(remote.calls, 1);
      expect(remote.lookups, 1);
      expect(cart.clears, 1);
    },
  );
  test(
    'resultado ausente permite reintentar con mismo ID y contenido original',
    () async {
      remote.failure = TimeoutException('Sin conexión');
      await vm.confirm(notes: 'original');
      final operationId = vm.operationId;
      remote.failure = null;
      await vm.confirm(notes: 'cambio no aplicado');
      expect(remote.received!['operationId'], operationId);
      expect(remote.received!['notes'], 'original');
      expect(remote.ids, 1);
      expect(remote.lookups, 1);
    },
  );
  test('consulta sin resultado no compra ni cambia ID', () async {
    remote.failure = TimeoutException('Sin respuesta');
    await vm.confirm();
    final id = vm.operationId;
    expect(await vm.confirm(consultOnly: true), isNull);
    expect(remote.calls, 1);
    expect(vm.operationId, id);
    expect(cart.clears, 0);
  });
  test('fallo de almacenamiento bloquea envío y mantiene carrito', () async {
    store.fail = true;
    expect(await vm.confirm(), isNull);
    expect(remote.calls, 0);
    expect(cart.clears, 0);
  });
  test('carrito editado durante respuesta no se vacía', () async {
    remote.delay = Completer<void>();
    final pending = vm.confirm();
    await Future<void>.delayed(Duration.zero);
    cart.items.single.quantity = 3;
    remote.delay!.complete();
    expect(await pending, isNotNull);
    expect(cart.clears, 0);
  });
  test('cambio de cuenta durante confirmación no vacía carrito ni borra recuperación', () async {
    remote.delay = Completer<void>();
    final pending = vm.confirm();
    await Future<void>.delayed(Duration.zero);
    uid = 'uid-b';
    remote.delay!.complete();
    expect(await pending, isNull);
    expect(cart.clears, 0);
    expect(store.values['uid-a'], isNotNull);
  });
  test('ni producción ni carrito vacío confirman', () async {
    expect(FirebaseEnvironment.emulatorOrdersEnabled, isFalse);
    remote.confirmationEnabled = false;
    expect(await vm.confirm(), isNull);
    expect(remote.calls, 0);
    remote.confirmationEnabled = true;
    cart.items.clear();
    expect(await vm.confirm(), isNull);
    expect(remote.calls, 0);
  });
  test('lectura cacheada no se presenta como compra confirmada', () async {
    remote.committed = remote.order('operation-1', cached: true);
    expect(await vm.confirm(), isNull);
    expect(cart.clears, 0);
    expect(vm.hasPending, isTrue);
  });
  test('mapper conserva PED001, importe histórico, unidades e historial', () {
    final order = FirestoreOrderMapper.fromMaps(
      documentId: 'PED001',
      ownerUid: 'uid-a',
      data: {
        'estado': 'pendiente',
        'fecha_pedido': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'id_cliente': 'FARM001',
        'id_direccion': 'DIR001',
        'total': 300,
      },
      details: [
        {
          'id_producto': 'PROD001',
          'cantidad': 2,
          'precio_unitario': 150,
          'subtotal': 300,
          'unidad_medida': 'Caja',
          'asignaciones_lotes': [
            {'id_lote': 'LOTE001', 'cantidad': 2},
          ],
        },
      ],
      history: {
        'event': {
          'estado': 'pendiente',
          'fecha': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'operacion': 'confirm',
        },
      },
    );
    expect(order.documentId, 'PED001');
    expect(order.number, 'PED001');
    expect(order.total, 300);
    expect(order.items.single.saleUnit, 'Caja');
    expect(order.lotAllocations.single.quantity, 2);
    expect(order.history.single.operation, 'confirm');
  });
}
