import 'package:flutter/foundation.dart';

import '../models/order.dart';

/// Notificación local de un cambio de estado de pedido (RF-15).
class AppNotification {
  const AppNotification({
    required this.orderNumber,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  final String orderNumber;
  final OrderStatus status;
  final String message;
  final DateTime createdAt;
}

/// Simula las notificaciones push de FCM mientras el backend no las expone.
///
/// El servicio escucha (es invocado por) los cambios de estado del pedido y
/// publica un aviso. La capa de UI decide cómo mostrarlo (SnackBar o
/// notificación local). También guarda un historial corto para la campana.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _maxHistory = 50;

  final List<AppNotification> _history = [];
  AppNotification? _latest;

  List<AppNotification> get history => List.unmodifiable(_history);

  AppNotification? get latest => _latest;

  bool get hasUnread => _latest != null;

  /// Registra el aviso producido por una transición de estado.
  void notifyOrderStatus(PharmacyOrder order, OrderStatus previous) {
    if (previous == order.status) return;
    final message = _messageFor(order, previous);
    if (message == null) return;

    final notification = AppNotification(
      orderNumber: order.number,
      status: order.status,
      message: message,
      createdAt: DateTime.now(),
    );
    _history.insert(0, notification);
    if (_history.length > _maxHistory) _history.removeLast();
    _latest = notification;
    notifyListeners();
  }

  void clear() {
    _history.clear();
    _latest = null;
    notifyListeners();
  }

  String? _messageFor(PharmacyOrder order, OrderStatus previous) {
    final number = order.number;
    return switch (order.status) {
      OrderStatus.pendiente => 'Pedido $number recibido y en revisión.',
      OrderStatus.aprobado =>
        order.scheduledFor != null
            ? 'Pedido $number reprogramado para el '
                  '${_shortDate(order.scheduledFor!)}. Vuelve a estar aprobado.'
            : 'Pedido $number aprobado. Ya puede asignarse un repartidor.',
      OrderStatus.enRuta =>
        'Pedido $number en ruta con ${order.driverName ?? 'un repartidor'}.',
      OrderStatus.entregado => 'Pedido $number entregado correctamente.',
      OrderStatus.reprogramado =>
        'Pedido $number reprogramado: '
            '${order.failureReason ?? 'la entrega no se completó'}. '
            'El vendedor asignará una nueva fecha.',
      OrderStatus.fallida => 'Pedido $number con entrega fallida.',
    };
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
