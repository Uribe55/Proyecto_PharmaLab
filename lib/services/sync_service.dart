import 'package:flutter/foundation.dart';

import '../domain/order_policy.dart';
import '../models/order.dart';
import '../models/order_lifecycle.dart';
import 'pharma_service.dart';

/// Evento local vinculado al actor y al intento que lo originó.
class PendingDelivery {
  PendingDelivery({
    required this.id,
    required this.orderNumber,
    required this.action,
    required this.registeredAt,
    required this.actorId,
    required this.attemptId,
    this.reason,
    this.note = '',
  });
  final String id, orderNumber, actorId;
  final String? attemptId, reason;
  final OrderAction action;
  final DateTime registeredAt;
  final String note;
  String? conflict;
  bool get delivered => action == OrderAction.deliver;
}

/// Cola de demostración en memoria: sin persistencia ni sincronización remota.
class SyncService extends ChangeNotifier {
  SyncService({PharmaService? service, DateTime Function()? clock})
    : _service = service ?? PharmaService.instance,
      _clock = clock ?? DateTime.now;
  static final SyncService instance = SyncService();
  final PharmaService _service;
  final DateTime Function() _clock;
  bool _offline = false;
  int _sequence = 0;
  final List<PendingDelivery> _queue = [];
  String? lastError;
  bool get isOffline => _offline;
  List<PendingDelivery> get pending => List.unmodifiable(
    _queue.where((item) => item.actorId == _service.currentUser?.id),
  );
  int get pendingCount => pending.length;
  bool isQueued(String orderNumber) => pendingFor(orderNumber) != null;
  PendingDelivery? pendingFor(String orderNumber) {
    for (final item in pending) {
      if (item.orderNumber == orderNumber) return item;
    }
    return null;
  }

  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }

  bool queueDelivery(
    PharmacyOrder order, {
    required bool delivered,
    String? reason,
    String note = '',
  }) => queueAction(
    order,
    delivered ? OrderAction.deliver : OrderAction.fail,
    reason: reason,
    note: note,
  );
  bool queueAction(
    PharmacyOrder order,
    OrderAction action, {
    String? reason,
    String note = '',
  }) {
    lastError = null;
    if (_service.usesFirebase ||
        !{
          OrderAction.deliver,
          OrderAction.fail,
          OrderAction.incident,
        }.contains(action)) {
      lastError = 'El registro remoto todavía no está habilitado.';
    } else {
      lastError = OrderPolicy.rejection(order, _service.currentUser, action);
    }
    if (lastError == null &&
        action != OrderAction.deliver &&
        (reason ?? '').trim().isEmpty) {
      lastError = 'Indica un motivo.';
    }
    if (lastError == null && isQueued(order.number)) lastError = 'Ya existe un evento pendiente para este pedido. Sincroniza o descártalo primero.';
    if (lastError != null) {
      notifyListeners();
      return false;
    }
    final now = _clock();
    _queue.add(
      PendingDelivery(
        id: '${_service.currentUser!.id}-${now.microsecondsSinceEpoch}-${++_sequence}',
        orderNumber: order.number,
        action: action,
        registeredAt: now,
        actorId: _service.currentUser!.id,
        attemptId: order.currentAttempt?.id,
        reason: reason,
        note: note,
      ),
    );
    notifyListeners();
    return true;
  }

  void discard(String orderNumber) {
    _queue.removeWhere(
      (item) =>
          item.orderNumber == orderNumber &&
          item.actorId == _service.currentUser?.id,
    );
    notifyListeners();
  }

  int syncNow() {
    if (_offline || _service.usesFirebase) return 0;
    var synced = 0;
    for (final action in List<PendingDelivery>.from(pending)) {
      PharmacyOrder? order;
      for (final candidate in _service.orders) {
        if (candidate.number == action.orderNumber) {
          order = candidate;
          break;
        }
      }
      if (order == null) {
        action.conflict = 'Pedido no disponible para este usuario.';
        continue;
      }
      final applied = _service.performOrderAction(
        order,
        action.action,
        reason: action.reason ?? '',
        note: action.note,
        eventId: action.id,
        expectedAttemptId: action.attemptId,
        occurredAt: action.registeredAt,
      );
      if (applied) {
        _queue.remove(action);
        synced++;
      } else {
        action.conflict =
            _service.lastOrderError ??
            'Conflicto de estado. Revisa el pedido antes de reintentar.';
      }
    }
    notifyListeners();
    return synced;
  }
}
