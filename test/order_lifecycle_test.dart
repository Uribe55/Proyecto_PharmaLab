import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_movil/data/datasources/local_order_data_source.dart';
import 'package:proyecto_final_movil/data/repositories/order_repository.dart';
import 'package:proyecto_final_movil/domain/order_policy.dart';
import 'package:proyecto_final_movil/models/app_user.dart';
import 'package:proyecto_final_movil/models/cart_item.dart';
import 'package:proyecto_final_movil/models/order.dart';
import 'package:proyecto_final_movil/models/order_lifecycle.dart';
import 'package:proyecto_final_movil/models/product.dart';
import 'package:proyecto_final_movil/services/pharma_service.dart';
import 'package:proyecto_final_movil/services/sync_service.dart';

AppUser actor(String id, UserRole role, {bool active = true}) => AppUser(
  id: id,
  name: id,
  email: '$id@test.bo',
  phone: '123',
  role: role,
  active: active,
);
final customer = actor('customer', UserRole.cliente);
final other = actor('other', UserRole.cliente);
final seller = actor('seller', UserRole.vendedor);
final admin = actor('admin', UserRole.administrador);
final driver = actor('driver', UserRole.repartidor);
final secondDriver = actor('driver2', UserRole.repartidor);

class Fixture {
  DateTime now = DateTime(2026, 11, 24, 10);
  bool remote = false;
  final orders = <PharmacyOrder>[];
  final product = Product(
    id: 'PROD001',
    name: 'Caja',
    brand: '',
    presentation: 'Caja',
    category: ProductCategory.reactivosQuimicaSanguinea,
    price: 150,
    stock: 10,
  );
  late final repo = OrderRepository(
    LocalOrderDataSource(
      orders: orders,
      products: [product],
      isRemote: () => remote,
      onChanged: () {},
    ),
    clock: () => now,
  );
  PharmacyOrder confirm() => repo.confirm(
    actor: customer,
    pharmacy: PharmaService.demoProfile,
    items: [CartItem(product: product, quantity: 2)],
  );
  PharmacyOrder approved() {
    final order = confirm();
    repo.execute(order, seller, OrderAction.approve);
    return order;
  }

  PharmacyOrder assigned() {
    final order = approved();
    repo.execute(order, seller, OrderAction.assign, driver: driver);
    return order;
  }

  PharmacyOrder inRoute() {
    final order = assigned();
    repo.execute(order, driver, OrderAction.dispatch);
    return order;
  }

  bool act(
    PharmacyOrder order,
    AppUser user,
    OrderAction action, {
    String reason = 'Motivo',
    AppUser? assigned,
  }) => repo.execute(order, user, action, reason: reason, driver: assigned);
}

class LocalSession extends ChangeNotifier implements PharmaService {
  LocalSession(this.f);
  final Fixture f;
  @override
  AppUser? currentUser = driver;
  @override
  bool get usesFirebase => f.remote;
  @override
  String? lastOrderError;
  @override
  List<PharmacyOrder> get orders =>
      f.orders.where((o) => OrderPolicy.canRead(o, currentUser)).toList();
  @override
  bool performOrderAction(
    PharmacyOrder order,
    OrderAction action, {
    String reason = '',
    String note = '',
    AppUser? driver,
    DateTime? scheduledFor,
    String? eventId,
    String? expectedAttemptId,
    DateTime? occurredAt,
  }) {
    try {
      return f.repo.execute(
        order,
        currentUser,
        action,
        reason: reason,
        note: note,
        driver: driver,
        scheduledFor: scheduledFor,
        eventId: eventId,
        expectedAttemptId: expectedAttemptId,
        occurredAt: occurredAt,
      );
    } on StateError catch (error) {
      lastOrderError = error.message.toString();
      return false;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Fixture f;
  setUp(() => f = Fixture());
  test('Pendiente propio cancela y restituye exactamente una vez', () {
    final order = f.confirm();
    expect(f.product.stock, 8);
    f.act(order, customer, OrderAction.cancel);
    expect(order.status, OrderStatus.cancelado);
    expect(f.product.stock, 10);
    expect(order.cancelledAt, f.now);
    expect(order.cancelledBy, customer.id);
    final count = order.history.length;
    f.act(order, customer, OrderAction.cancel);
    expect(order.history.length, count);
    expect(f.product.stock, 10);
  });
  test('No cancela ni consulta un cliente ajeno', () {
    final order = f.confirm();
    expect(OrderPolicy.canRead(order, other), isFalse);
    expect(() => f.act(order, other, OrderAction.cancel), throwsStateError);
    expect(f.product.stock, 8);
  });
  test('Cancelación sin motivo no cambia el pedido', () {
    final order = f.confirm();
    expect(
      () => f.act(order, customer, OrderAction.cancel, reason: ''),
      throwsStateError,
    );
    expect(order.isPending, isTrue);
  });
  test('Aprobado solicita una sola cancelación y vendedor la aprueba', () {
    final order = f.assigned();
    expect(() => f.act(order, customer, OrderAction.cancel), throwsStateError);
    f.act(order, customer, OrderAction.requestCancellation);
    expect(order.isApproved, isTrue);
    expect(
      () => f.act(order, customer, OrderAction.requestCancellation),
      throwsStateError,
    );
    f.act(order, seller, OrderAction.acceptCancellation);
    expect(
      order.cancellationRequests.single.status,
      CancellationStatus.accepted,
    );
    expect(order.status, OrderStatus.cancelado);
    expect(f.product.stock, 10);
  });
  test('Administrador rechaza con motivo sin restituir stock', () {
    final order = f.approved();
    f.act(order, customer, OrderAction.requestCancellation);
    f.act(order, admin, OrderAction.rejectCancellation);
    expect(order.isApproved, isTrue);
    expect(f.product.stock, 8);
    expect(order.cancellationRequests.single.resolvedBy, admin.id);
    expect(order.pendingCancellation, isNull);
    f.act(order, customer, OrderAction.requestCancellation);
    expect(order.cancellationRequests.length, 2);
  });
  test('Revalida despacho antes de aprobar una cancelación', () {
    final order = f.assigned();
    f.act(order, customer, OrderAction.requestCancellation);
    f.act(order, driver, OrderAction.dispatch);
    expect(
      () => f.act(order, seller, OrderAction.acceptCancellation),
      throwsStateError,
    );
    expect(
      () => f.act(order, customer, OrderAction.requestCancellation),
      throwsStateError,
    );
    expect(() => f.act(order, customer, OrderAction.cancel), throwsStateError);
    f.act(order, seller, OrderAction.rejectCancellation);
    expect(f.product.stock, 8);
  });
  for (final terminal in [OrderStatus.entregado, OrderStatus.cancelado]) {
    test('Terminal ${terminal.name} no se reactiva para ningún rol', () {
      final order = f.confirm();
      order.status = terminal;
      for (final user in [customer, seller, admin, driver]) {
        for (final action in OrderAction.values) {
          if (terminal == OrderStatus.cancelado &&
              action == OrderAction.cancel) {
            continue;
          }
          expect(
            () => f.act(order, user, action),
            throwsStateError,
            reason: '${user.role.name}: ${action.name}',
          );
        }
      }
    });
  }
  test('Asignación y reasignación no despachan y quedan trazadas', () {
    final order = f.assigned();
    expect(order.isApproved, isTrue);
    expect(order.dispatchedAt, isNull);
    expect(order.assignedBy, seller.id);
    expect(order.attempts, isEmpty);
    f.act(order, seller, OrderAction.assign, assigned: secondDriver);
    expect(order.history.where((e) => e.operation == 'assign').length, 2);
    expect(
      order.history.firstWhere((e) => e.operation == 'assign').note,
      contains(driver.id),
    );
    expect(() => f.act(order, driver, OrderAction.dispatch), throwsStateError);
    f.act(order, secondDriver, OrderAction.dispatch);
    expect(order.dispatchedBy, secondDriver.id);
    expect(order.attempts.single.result, AttemptResult.inProgress);
  });
  test('Despacho sin repartidor y asignación inactiva son rechazados', () {
    final order = f.approved();
    expect(() => f.act(order, seller, OrderAction.dispatch), throwsStateError);
    expect(
      () => f.act(
        order,
        seller,
        OrderAction.assign,
        assigned: actor('x', UserRole.repartidor, active: false),
      ),
      throwsStateError,
    );
  });
  test('Incidencia temporal no cierra intento ni cancela', () {
    final order = f.inRoute();
    f.act(order, driver, OrderAction.incident, reason: 'Avería de vehículo');
    expect(order.isInTransit, isTrue);
    expect(order.currentAttempt!.closedAt, isNull);
    expect(order.incidents.single.attemptId, order.currentAttempt!.id);
    expect(order.deliveredAt, isNull);
    expect(f.product.stock, 8);
    f.act(
      order,
      customer,
      OrderAction.incident,
      reason: 'Dirección incorrecta',
    );
    expect(order.incidents.length, 2);
  });
  test(
    'Fallo, reprogramación y nuevo intento entregado conservan antecedentes',
    () {
      final order = f.inRoute();
      f.act(order, driver, OrderAction.fail, reason: 'Farmacia cerrada');
      expect(order.status, OrderStatus.reprogramado);
      expect(order.isRescheduled, isTrue);
      expect(order.deliveredAt, isNull);
      expect(order.failedAt, f.now);
      expect(f.product.stock, 8);
      f.act(order, seller, OrderAction.reschedule);
      expect(order.isApproved, isTrue);
      expect(order.attempts.length, 2);
      expect(order.attempts.first.reason, 'Farmacia cerrada');
      expect(order.currentAttempt!.result, AttemptResult.prepared);
      expect(
        () => f.act(order, customer, OrderAction.requestCancellation),
        throwsStateError,
      );
      f.act(order, driver, OrderAction.dispatch);
      f.act(order, driver, OrderAction.fail, reason: 'Cliente ausente');
      f.act(order, admin, OrderAction.reschedule);
      f.act(order, driver, OrderAction.dispatch);
      f.now = f.now.add(const Duration(hours: 1));
      f.act(order, driver, OrderAction.deliver);
      expect(f.orders.length, 1);
      expect(order.attempts.length, 3);
      expect(order.deliveredAt, f.now);
      expect(order.attempts.last.closedAt, f.now);
      expect(order.attempts.first.result, AttemptResult.failed);
      expect(order.attempts[1].reason, 'Cliente ausente');
      expect(f.product.stock, 8);
      expect(order.history.map((e) => e.operation), [
        'confirm',
        'approve',
        'assign',
        'dispatch',
        'fail',
        'reschedule',
        'dispatch',
        'fail',
        'reschedule',
        'dispatch',
        'deliver',
      ]);
      expect(order.history.last.toMap()['pedido_id'], order.number);
    },
  );
  test('No despacha antes de la reprogramación autorizada', () {
    final order = f.inRoute();
    f.act(order, driver, OrderAction.fail);
    final scheduled = f.now.add(const Duration(days: 1));
    f.repo.execute(
      order,
      seller,
      OrderAction.reschedule,
      reason: 'Mañana',
      scheduledFor: scheduled,
    );
    expect(() => f.act(order, driver, OrderAction.dispatch), throwsStateError);
    f.now = scheduled;
    f.act(order, driver, OrderAction.dispatch);
    expect(order.isInTransit, isTrue);
  });
  test(
    'Solo repartidor autorizado puede cerrar intento; gestor no entrega',
    () {
      final order = f.inRoute();
      for (final user in [customer, other, seller, admin, secondDriver]) {
        expect(() => f.act(order, user, OrderAction.deliver), throwsStateError);
        expect(() => f.act(order, user, OrderAction.fail), throwsStateError);
      }
      expect(() => f.act(order, driver, OrderAction.approve), throwsStateError);
      expect(
        () => f.act(order, customer, OrderAction.assign, assigned: driver),
        throwsStateError,
      );
    },
  );
  test('Pedido histórico no inventa un descuento ni repone existencias', () {
    final order = f.confirm();
    order.localStockDebits.clear();
    f.act(order, customer, OrderAction.cancel);
    expect(f.product.stock, 8);
    final old = PharmacyOrder(
      number: 'legacy',
      createdAt: f.now,
      status: OrderStatus.fallida,
      items: [],
      pharmacyName: '',
      address: '',
      contactName: '',
      contactPhone: '',
      customerId: customer.id,
      driverId: driver.id,
      deliveredAt: f.now,
      failureReason: 'Fallo histórico',
    );
    f.orders.add(old);
    expect(old.deliveredAt, isNull);
    expect(old.failedAt, f.now);
    f.act(old, seller, OrderAction.reschedule);
    expect(old.attempts.first.reason, 'Fallo histórico');
    expect(old.attempts.length, 2);
  });
  test(
    'Valida cantidades agregadas antes de descontar; nunca stock negativo',
    () {
      final line = CartItem(product: f.product, quantity: 6);
      expect(
        () => f.repo.confirm(
          actor: customer,
          pharmacy: PharmaService.demoProfile,
          items: [line, line],
        ),
        throwsA(isA<OrderStockException>()),
      );
      expect(f.product.stock, 10);
      expect(f.orders, isEmpty);
      expect(
        () => f.repo.confirm(
          actor: customer,
          pharmacy: PharmaService.demoProfile,
          items: [CartItem(product: f.product, quantity: -1)],
        ),
        throwsStateError,
      );
    },
  );
  test('Bloqueo Firebase se verifica también en el repositorio', () {
    final order = f.inRoute();
    f.remote = true;
    expect(() => f.act(order, driver, OrderAction.deliver), throwsStateError);
    expect(() => f.confirm(), throwsStateError);
    expect(f.product.stock, 8);
  });
  test(
    'Evento duplicado se aplica una sola vez incluso tras cambiar el estado',
    () {
      final order = f.inRoute();
      f.repo.execute(order, driver, OrderAction.deliver, eventId: 'event-1');
      final count = order.history.length;
      f.repo.execute(order, driver, OrderAction.deliver, eventId: 'event-1');
      expect(order.history.length, count);
    },
  );
  test('Cola offline conserva actor, fecha e intento y evita duplicados', () {
    final order = f.inRoute();
    final session = LocalSession(f);
    final sync = SyncService(service: session, clock: () => f.now)
      ..setOffline(true);
    expect(sync.queueDelivery(order, delivered: true), isTrue);
    expect(
      sync.queueDelivery(order, delivered: false, reason: 'Otro'),
      isFalse,
    );
    expect(sync.pendingCount, 1);
    expect(sync.syncNow(), 0);
    expect(order.isInTransit, isTrue);
    session.currentUser = secondDriver;
    sync.setOffline(false);
    expect(sync.syncNow(), 0);
    expect(sync.pendingCount, 0);
    session.currentUser = driver;
    expect(sync.pendingCount, 1);
    expect(sync.syncNow(), 1);
    expect(order.deliveredAt, f.now);
    expect(sync.syncNow(), 0);
    sync.dispose();
    session.dispose();
  });
  test(
    'Conflicto offline no elimina evento ni sobrescribe un nuevo intento',
    () {
      final order = f.inRoute();
      final session = LocalSession(f);
      final sync = SyncService(service: session, clock: () => f.now)
        ..setOffline(true);
      sync.queueDelivery(order, delivered: true);
      f.act(order, driver, OrderAction.fail);
      f.act(order, seller, OrderAction.reschedule);
      f.act(order, driver, OrderAction.dispatch);
      sync.setOffline(false);
      expect(sync.syncNow(), 0);
      expect(sync.pendingCount, 1);
      expect(sync.pending.single.conflict, isNotNull);
      expect(order.isInTransit, isTrue);
      expect(order.deliveredAt, isNull);
      sync.dispose();
      session.dispose();
    },
  );
}
