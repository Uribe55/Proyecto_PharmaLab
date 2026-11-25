import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/repositories/staff_order_repository.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/viewmodels/seller_orders_view_model.dart';

class StaffFake implements StaffOrderRepository {
  final feeds = <StreamController<StaffOrderFeed>>[];
  int cancellations = 0;
  @override
  bool get approvalEnabled => false;
  @override
  Future<void> approve(String orderId) async => throw StateError('Bloqueada');
  @override
  Stream<StaffOrderFeed> watchOrders() {
    final controller = StreamController<StaffOrderFeed>(
      sync: true,
      onCancel: () {
        cancellations++;
      },
    );
    feeds.add(controller);
    return controller.stream;
  }

  @override
  Stream<PharmacyOrder> watchOrder(String orderId) => const Stream.empty();
}

PharmacyOrder realOrder(
  String id, [
  OrderStatus status = OrderStatus.pendiente,
]) => PharmacyOrder(
  number: id,
  documentId: id,
  createdAt: DateTime.utc(2026),
  status: status,
  items: [],
  pharmacyName: 'FARM001',
  address: '',
  contactName: '',
  contactPhone: '',
  remote: true,
);

void main() {
  late ValueNotifier<String?> session;
  late StaffFake repository;
  late SellerOrdersViewModel vm;
  setUp(() {
    session = ValueNotifier<String?>('vendedor');
    repository = StaffFake();
    vm = SellerOrdersViewModel(
      repository: repository,
      sessionChanges: session,
      authorizedUid: () => session.value,
    );
  });
  tearDown(() async {
    vm.dispose();
    session.dispose();
    for (final feed in repository.feeds) {
      await feed.close();
    }
  });

  test('stream inicial sin alertas, llegada nueva y contador actualizado', () {
    repository.feeds.single.add(
      StaffOrderFeed([realOrder('PED001', OrderStatus.aprobado)]),
    );
    expect(vm.pendingCount, 0);
    expect(vm.notificationVersion, 0);
    repository.feeds.single.add(
      StaffOrderFeed([
        realOrder('nuevo'),
        realOrder('PED001', OrderStatus.aprobado),
      ]),
    );
    expect(vm.pendingCount, 1);
    expect(vm.notificationVersion, 1);
    expect(vm.newPendingCount, 1);
    expect(vm.orders.every((o) => o.remote), isTrue);
  });

  test('modificar un pedido y repetir metadatos no repite avisos', () {
    repository.feeds.single.add(const StaffOrderFeed([]));
    repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
    repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
    repository.feeds.single.add(
      StaffOrderFeed([realOrder('nuevo', OrderStatus.aprobado)]),
    );
    expect(vm.notificationVersion, 1);
    expect(vm.pendingCount, 0);
  });

  test('cache y primera respuesta servidor no anuncian pedidos históricos', () {
    repository.feeds.single.add(
      StaffOrderFeed([realOrder('PED001')], fromCache: true),
    );
    expect(vm.fromCache, isTrue);
    expect(vm.notificationVersion, 0);
    repository.feeds.single.add(StaffOrderFeed([realOrder('PED001')]));
    expect(vm.fromCache, isFalse);
    expect(vm.notificationVersion, 0);
  });

  test('un pedido retirado y vuelto a recibir no se anuncia dos veces', () {
    repository.feeds.single.add(const StaffOrderFeed([]));
    repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
    repository.feeds.single.add(const StaffOrderFeed([]));
    repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
    expect(vm.notificationVersion, 1);
  });

  test('logout cancela la escucha y borra los datos visibles', () {
    repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
    session.value = null;
    expect(repository.cancellations, 1);
    expect(vm.orders, isEmpty);
    expect(vm.loading, isFalse);
    expect(vm.pendingCount, 0);
  });

  test('cambio de cuenta inicia una escucha sin reutilizar pedidos', () {
    repository.feeds.single.add(StaffOrderFeed([realOrder('anterior')]));
    session.value = 'otro-vendedor';
    expect(repository.cancellations, 1);
    expect(vm.orders, isEmpty);
    repository.feeds.last.add(StaffOrderFeed([realOrder('otra-cuenta')]));
    expect(vm.orders.single.number, 'otra-cuenta');
    expect(vm.notificationVersion, 0);
  });

  test(
    'error de permisos limpia resultados y no carga datos de demostración',
    () {
      repository.feeds.single.add(StaffOrderFeed([realOrder('nuevo')]));
      repository.feeds.single.addError(StateError('permission-denied'));
      expect(vm.orders, isEmpty);
      expect(vm.error, contains('permisos'));
      expect(vm.loading, isFalse);
    },
  );

  test('sin una sesión autorizada no existe una suscripción', () {
    session.value = null;
    final deniedRepository = StaffFake();
    final denied = SellerOrdersViewModel(
      repository: deniedRepository,
      sessionChanges: session,
      authorizedUid: () => null,
    );
    expect(deniedRepository.feeds, isEmpty);
    denied.dispose();
  });
}
