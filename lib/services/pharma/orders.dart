part of '../pharma_service.dart';

/// Pedidos locales, asignaciones y estados de entrega.
mixin _PharmaOrders on _PharmaServiceState {
  List<PharmacyOrder> get orders => List.unmodifiable(_orders);

  List<PharmacyOrder> get pendingOrders =>
      _orders.where((order) => order.isPending).toList();

  List<PharmacyOrder> get approvedOrders =>
      _orders.where((order) => order.isApproved).toList();

  List<PharmacyOrder> ordersForDriver(String driverId) =>
      _orders.where((order) => order.driverId == driverId).toList();

  int activeDeliveriesFor(String driverId) => _orders
      .where((order) => order.driverId == driverId && order.isInTransit)
      .length;

  /// Confirma un pedido: valida stock, lo descuenta y genera el número único.
  ///
  /// Los pedidos siguen siendo locales: la colección de Firestore todavía no
  /// incluye pedidos, por lo que se conserva el flujo de demostración.
  PharmacyOrder createOrder({
    required List<CartItem> items,
    String notes = '',
  }) {
    if (!isLoggedIn) throw StateError('No hay una sesión activa.');
    if (usesFirebase && _uid != null) {
      throw StateError(
        'Los pedidos reales se habilitarán en la siguiente etapa.',
      );
    }
    if (items.isEmpty) throw StateError('El carrito está vacío.');

    // Primera pasada: validar todo antes de tocar el stock.
    for (final item in items) {
      final product = _products.firstWhere((p) => p.id == item.product.id);
      if (item.quantity <= 0 || item.quantity > product.stock) {
        throw StockUnavailableException(product.name, product.stock);
      }
    }

    // Segunda pasada: descontar stock (RF-08).
    for (final item in items) {
      final product = _products.firstWhere((p) => p.id == item.product.id);
      product.stock -= item.quantity;
    }

    final customer = pharmacy;
    final order = PharmacyOrder(
      number: _nextOrderNumber(),
      createdAt: DateTime.now(),
      status: OrderStatus.pendiente,
      pharmacyName: customer.commercialName,
      address: customer.address,
      contactName: customer.responsible,
      contactPhone: customer.phone,
      notes: notes.trim(),
      items: items
          .map(
            (item) => OrderLine(
              productId: item.product.id,
              name: item.product.name,
              brand: item.product.brand,
              presentation: item.product.presentation,
              unitPrice: item.product.price,
              quantity: item.quantity,
            ),
          )
          .toList(),
    );

    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  /// Aprueba un pedido pendiente (RF-11).
  bool approveOrder(PharmacyOrder order) {
    if (!order.isPending) return false;
    final previous = order.status;
    order.status = OrderStatus.aprobado;
    NotificationService.instance.notifyOrderStatus(order, previous);
    notifyListeners();
    return true;
  }

  /// Asigna un pedido aprobado a un repartidor y lo pone en ruta (RF-12).
  bool assignDelivery(PharmacyOrder order, AppUser driver) {
    if (!order.canAssignDriver) return false;
    if (driver.role != UserRole.repartidor || !driver.active) return false;

    // El repartidor guarda el correo institucional en lugar de datos de más.
    final previous = order.status;
    order
      ..driverId = driver.id
      ..driverName = driver.name
      ..status = OrderStatus.enRuta
      ..deliveredAt = null
      ..failureReason = null
      ..failureNote = null;
    NotificationService.instance.notifyOrderStatus(order, previous);
    notifyListeners();
    return true;
  }

  /// Marca el pedido como entregado con fecha y hora (RF-14).
  bool markDelivered(PharmacyOrder order) {
    if (!order.canDeliver) return false;
    final previous = order.status;
    order
      ..status = OrderStatus.entregado
      ..failureReason = null
      ..failureNote = null
      ..deliveredAt = DateTime.now();
    NotificationService.instance.notifyOrderStatus(order, previous);
    notifyListeners();
    return true;
  }

  /// Registra una entrega fallida con su motivo (RF-17).
  ///
  /// El pedido no se cancela: queda en estado "Reprogramado" y regresa al
  /// panel del vendedor para que asigne una nueva fecha de entrega.
  bool markDeliveryFailed(
    PharmacyOrder order, {
    required String reason,
    String note = '',
  }) {
    if (!order.canDeliver) return false;
    final previous = order.status;
    order
      ..status = OrderStatus.reprogramado
      ..failureReason = reason
      ..failureNote = note.trim()
      ..deliveredAt = DateTime.now();
    NotificationService.instance.notifyOrderStatus(order, previous);
    notifyListeners();
    return true;
  }

  /// El vendedor fija una nueva fecha para un pedido reprogramado (RF-17).
  ///
  /// Al reprogramar, el pedido vuelve a "Aprobado" para que pueda asignarse
  /// a un repartidor en la nueva fecha.
  bool rescheduleOrder(PharmacyOrder order, DateTime newDate) {
    if (!order.needsReschedule) return false;
    final previous = order.status;
    order
      ..status = OrderStatus.aprobado
      ..scheduledFor = newDate
      ..deliveredAt = null
      ..driverId = null
      ..driverName = null;
    NotificationService.instance.notifyOrderStatus(order, previous);
    notifyListeners();
    return true;
  }

  String _nextOrderNumber() {
    var maxSequence = 0;
    for (final order in _orders) {
      final sequence = int.tryParse(order.number.split('-').last) ?? 0;
      if (sequence > maxSequence) maxSequence = sequence;
    }

    final next = (maxSequence + 1).toString().padLeft(4, '0');
    return 'PL-${DateTime.now().year}-$next';
  }
}
