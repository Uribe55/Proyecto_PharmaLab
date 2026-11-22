import 'package:flutter/foundation.dart';

import '../models/order.dart';
import 'pharma_service.dart';

/// Acción de entrega registrada por el repartidor mientras no tiene conexión.
class PendingDelivery {
  const PendingDelivery({
    required this.orderNumber,
    required this.delivered,
    required this.registeredAt,
    this.reason,
    this.note = '',
  });

  final String orderNumber;
  final bool delivered;
  final DateTime registeredAt;
  final String? reason;
  final String note;
}

/// Simula la conectividad del repartidor para el RF-18.
///
/// Cuando no hay conexión, las entregas se guardan en una cola local y se
/// aplican sobre los pedidos al sincronizar. La lógica vive en un servicio
/// (RNF-11) para poder sustituirla por Firebase más adelante.
class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  bool _offline = false;
  final List<PendingDelivery> _queue = [];

  bool get isOffline => _offline;

  List<PendingDelivery> get pending => List.unmodifiable(_queue);

  int get pendingCount => _queue.length;

  bool isQueued(String orderNumber) =>
      _queue.any((item) => item.orderNumber == orderNumber);

  PendingDelivery? pendingFor(String orderNumber) {
    for (final item in _queue) {
      if (item.orderNumber == orderNumber) return item;
    }
    return null;
  }

  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }

  /// Guarda la entrega para aplicarla cuando vuelva la conexión.
  void queueDelivery(
    PharmacyOrder order, {
    required bool delivered,
    String? reason,
    String note = '',
  }) {
    _queue.removeWhere((item) => item.orderNumber == order.number);
    _queue.add(
      PendingDelivery(
        orderNumber: order.number,
        delivered: delivered,
        registeredAt: DateTime.now(),
        reason: reason,
        note: note,
      ),
    );
    notifyListeners();
  }

  void discard(String orderNumber) {
    _queue.removeWhere((item) => item.orderNumber == orderNumber);
    notifyListeners();
  }

  /// Aplica las entregas pendientes sobre los pedidos locales.
  /// Devuelve la cantidad de acciones sincronizadas.
  int syncNow() {
    if (_queue.isEmpty) return 0;

    final orders = PharmaService.instance.orders;
    var synced = 0;

    for (final action in List<PendingDelivery>.from(_queue)) {
      final order = _find(orders, action.orderNumber);
      if (order == null) continue;

      final applied = action.delivered
          ? PharmaService.instance.markDelivered(order)
          : PharmaService.instance.markDeliveryFailed(
              order,
              reason: action.reason ?? 'No se pudo completar la entrega',
              note: action.note,
            );
      if (applied) synced++;
    }

    _queue.clear();
    notifyListeners();
    return synced;
  }

  PharmacyOrder? _find(List<PharmacyOrder> orders, String number) {
    for (final order in orders) {
      if (order.number == number) return order;
    }
    return null;
  }
}
