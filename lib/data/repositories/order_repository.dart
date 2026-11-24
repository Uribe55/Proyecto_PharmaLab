import '../../domain/order_policy.dart';
import '../../models/app_user.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/order_lifecycle.dart';
import '../../models/pharmacy.dart';
import '../datasources/local_order_data_source.dart';

class OrderStockException implements Exception {
  const OrderStockException(this.name, this.available);
  final String name;
  final int available;
}

/// Unidad de trabajo síncrona local: valida todo antes de mutar inventario.
/// Ninguna operación de este repositorio accede a Firebase.
class OrderRepository {
  OrderRepository(this.source, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final LocalOrderDataSource source;
  final DateTime Function() _clock;
  int _sequence = 0;
  String _id() => '${_clock().microsecondsSinceEpoch}-${++_sequence}';
  void _local(PharmacyOrder? order) {
    if (source.isRemote() || (order?.remote ?? false)) {
      throw StateError(
        'Operación disponible solo en demostración local. Firebase pendiente.',
      );
    }
    if (order != null && !source.orders.contains(order)) {
      throw StateError('Pedido no encontrado.');
    }
  }

  void _record(
    PharmacyOrder order,
    AppUser actor,
    OrderStatus before,
    String operation,
    String note, {
    String? id,
    DateTime? at,
  }) {
    order.history.add(
      OrderHistoryEvent(
        id: id ?? _id(),
        orderNumber: order.number,
        before: before,
        after: order.status,
        operation: operation,
        at: at ?? _clock(),
        actorId: actor.id,
        role: actor.role,
        note: note,
      ),
    );
  }

  PharmacyOrder confirm({
    required AppUser? actor,
    required PharmacyProfile pharmacy,
    required List<CartItem> items,
    String notes = '',
  }) {
    _local(null);
    if (actor == null || !actor.active || actor.role != UserRole.cliente) {
      throw StateError('Solo una farmacia activa puede confirmar su pedido.');
    }
    if (items.isEmpty) throw StateError('El carrito está vacío.');
    final quantities = <String, int>{};
    for (final item in items) {
      if (item.quantity <= 0 || !item.availableInCatalog) {
        throw StateError('Cantidad o producto inválido.');
      }
      quantities.update(
        item.product.id,
        (q) => q + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    final products = {for (final p in source.products) p.id: p};
    for (final entry in quantities.entries) {
      final product = products[entry.key];
      if (product == null || product.stock < entry.value || product.stock < 0) {
        throw OrderStockException(
          product?.name ?? entry.key,
          product?.stock ?? 0,
        );
      }
    }
    var maximum = 0;
    for (final order in source.orders) {
      final value = int.tryParse(order.number.split('-').last) ?? 0;
      if (value > maximum) maximum = value;
    }
    final now = _clock();
    final order = PharmacyOrder(
      number: 'PL-${now.year}-${(maximum + 1).toString().padLeft(4, '0')}',
      createdAt: now,
      status: OrderStatus.pendiente,
      customerId: actor.id,
      pharmacyName: pharmacy.commercialName,
      address: pharmacy.address,
      contactName: pharmacy.responsible,
      contactPhone: pharmacy.phone,
      notes: notes.trim(),
      items: [
        for (final entry in quantities.entries)
          OrderLine(
            productId: entry.key,
            name: products[entry.key]!.name,
            brand: products[entry.key]!.brand,
            presentation: products[entry.key]!.presentation,
            unitPrice: products[entry.key]!.price,
            quantity: entry.value,
          ),
      ],
    );
    for (final entry in quantities.entries) {
      products[entry.key]!.stock -= entry.value;
    }
    order.localStockDebits.addAll(quantities);
    _record(
      order,
      actor,
      OrderStatus.pendiente,
      OrderAction.confirm.name,
      'Confirmación local y descuento único de unidades comerciales.',
    );
    source.orders.insert(0, order);
    source.onChanged();
    return order;
  }

  bool execute(
    PharmacyOrder order,
    AppUser? actor,
    OrderAction action, {
    String reason = '',
    String note = '',
    AppUser? driver,
    DateTime? scheduledFor,
    String? eventId,
    String? expectedAttemptId,
    DateTime? occurredAt,
  }) {
    _local(order);
    if (!OrderPolicy.canRead(order, actor)) {
      throw StateError('No tienes acceso a este pedido.');
    }
    final user = actor!;
    if (eventId != null && order.appliedEventIds.contains(eventId)) {
      if (order.history.any(
        (e) =>
            e.id == eventId &&
            e.actorId == user.id &&
            e.operation == action.name,
      )) {
        return true;
      }
      throw StateError('Identificador de evento incompatible.');
    }
    if (action == OrderAction.cancel &&
        order.status == OrderStatus.cancelado &&
        order.cancelledBy == user.id) {
      return true;
    }
    final rejection = OrderPolicy.rejection(order, user, action);
    if (rejection != null) throw StateError(rejection);
    if (expectedAttemptId != null &&
        order.currentAttempt?.id != expectedAttemptId) {
      throw StateError('Conflicto: el intento de entrega cambió.');
    }
    if ({
          OrderAction.cancel,
          OrderAction.requestCancellation,
          OrderAction.acceptCancellation,
          OrderAction.rejectCancellation,
          OrderAction.incident,
          OrderAction.fail,
          OrderAction.reschedule,
          OrderAction.coordinate,
          OrderAction.escalate,
        }.contains(action) &&
        reason.trim().isEmpty) {
      throw StateError('Indica un motivo.');
    }
    if (action == OrderAction.assign &&
        (driver == null ||
            !driver.active ||
            driver.role != UserRole.repartidor)) {
      throw StateError('Selecciona un repartidor activo.');
    }
    if (action == OrderAction.dispatch &&
        order.rescheduledFor != null &&
        _clock().isBefore(order.rescheduledFor!)) {
      throw StateError('La fecha de reprogramación todavía no llegó.');
    }
    if (action == OrderAction.reschedule &&
        scheduledFor != null &&
        scheduledFor.isBefore(_clock())) {
      throw StateError('La reprogramación no puede estar en el pasado.');
    }
    if ({OrderAction.cancel, OrderAction.acceptCancellation}.contains(action) &&
        !order.stockRestored) {
      final stock = {for (final p in source.products) p.id: p};
      for (final debit in order.localStockDebits.entries) {
        if (!stock.containsKey(debit.key) ||
            debit.value <= 0 ||
            stock[debit.key]!.stock < 0) {
          throw StateError(
            'No se puede restituir el inventario local de forma segura.',
          );
        }
      }
    }
    final before = order.status;
    final now = occurredAt ?? _clock();
    final id = eventId ?? _id();
    final details = [
      reason.trim(),
      note.trim(),
    ].where((s) => s.isNotEmpty).join(' · ');
    switch (action) {
      case OrderAction.confirm:
        throw StateError('Usa la confirmación local validada.');
      case OrderAction.approve:
        order.status = OrderStatus.aprobado;
      case OrderAction.assign:
        order.driverId = driver!.id;
        order.driverName = driver.name;
        order.assignedBy = user.id;
        order.assignedAt = now;
        if (order.currentAttempt?.result == AttemptResult.prepared) {
          order.currentAttempt!.driverId = driver.id;
        }
      case OrderAction.dispatch:
        order.status = OrderStatus.enRuta;
        order.dispatchedAt = now;
        order.dispatchedBy = user.id;
        order.hasBeenDispatched = true;
        final prepared = order.currentAttempt;
        if (prepared != null && prepared.result == AttemptResult.prepared) {
          prepared.startedAt = now;
          prepared.result = AttemptResult.inProgress;
        } else {
          order.attempts.add(
            DeliveryAttempt(
              id: '$id-attempt',
              orderNumber: order.number,
              number: order.attempts.length + 1,
              driverId: order.driverId!,
              startedAt: now,
              result: AttemptResult.inProgress,
            ),
          );
        }
      case OrderAction.cancel || OrderAction.acceptCancellation:
        if (action == OrderAction.acceptCancellation) {
          final request = order.pendingCancellation!;
          request.status = CancellationStatus.accepted;
          request.resolvedBy = user.id;
          request.resolvedAt = now;
          request.resolution = details;
        }
        if (!order.stockRestored) {
          for (final debit in order.localStockDebits.entries) {
            source.products.firstWhere((p) => p.id == debit.key).stock +=
                debit.value;
          }
          order.stockRestored = true;
        }
        order.status = OrderStatus.cancelado;
        order.cancelledAt = now;
        order.cancelledBy = user.id;
        order.cancellationReason = details;
      case OrderAction.requestCancellation:
        order.cancellationRequests.add(
          CancellationRequest(
            id: '$id-request',
            requestedBy: user.id,
            reason: details,
            requestedAt: now,
          ),
        );
      case OrderAction.rejectCancellation:
        final request = order.pendingCancellation!;
        request.status = CancellationStatus.rejected;
        request.resolvedBy = user.id;
        request.resolvedAt = now;
        request.resolution = details;
      case OrderAction.incident:
        order.incidents.add(
          DeliveryIncident(
            id: id,
            orderNumber: order.number,
            actorId: user.id,
            reason: reason.trim(),
            note: note.trim(),
            at: now,
            attemptId: order.currentAttempt?.id,
            outcome: user.role == UserRole.cliente
                ? 'Problema comunicado por la farmacia; pendiente de coordinación'
                : 'Temporal; continúa el intento',
          ),
        );
      case OrderAction.fail || OrderAction.deliver:
        final attempt = order.currentAttempt;
        if (attempt == null || attempt.result != AttemptResult.inProgress) {
          throw StateError('No hay un intento activo.');
        }
        attempt.closedAt = now;
        attempt.note = note.trim();
        if (action == OrderAction.deliver) {
          attempt.result = AttemptResult.delivered;
          order.status = OrderStatus.entregado;
          order.deliveredAt = now;
        } else {
          attempt.result = AttemptResult.failed;
          attempt.reason = reason.trim();
          order.status = OrderStatus.fallida;
          order.failedAt = now;
          order.failureReason = reason.trim();
          order.failureNote = note.trim();
          order.incidents.add(
            DeliveryIncident(
              id: id,
              orderNumber: order.number,
              actorId: user.id,
              reason: reason.trim(),
              note: note.trim(),
              at: now,
              attemptId: attempt.id,
              outcome: 'Intento fallido; requiere coordinación',
            ),
          );
        }
      case OrderAction.reschedule:
        if (order.attempts.isEmpty) {
          order.attempts.add(
            DeliveryAttempt(
              id: '$id-legacy',
              orderNumber: order.number,
              number: 1,
              driverId: order.driverId ?? '',
              startedAt: order.dispatchedAt,
              closedAt: order.failedAt,
              result: AttemptResult.failed,
              reason: order.failureReason,
              note: order.failureNote ?? '',
            ),
          );
        }
        order.attempts.add(
          DeliveryAttempt(
            id: '$id-next',
            orderNumber: order.number,
            number: order.attempts.length + 1,
            driverId: order.driverId ?? '',
          ),
        );
        order.status = OrderStatus.aprobado;
        order.dispatchedAt = null;
        order.dispatchedBy = null;
        order.rescheduledFor = scheduledFor ?? now;
      case OrderAction.coordinate || OrderAction.escalate:
        break;
    }
    _record(
      order,
      user,
      before,
      action.name,
      action == OrderAction.assign
          ? '$details Repartidor: ${driver!.id}'
          : action == OrderAction.reschedule
          ? '$details Fecha: ${order.rescheduledFor!.toIso8601String()}'
          : details,
      id: id,
      at: now,
    );
    order.appliedEventIds.add(id);
    source.onChanged();
    return true;
  }
}
