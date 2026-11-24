part of '../pharma_service.dart';

/// Adaptador incremental: conserva la API pública y delega el dominio local.
mixin _PharmaOrders on _PharmaServiceState {
  OrderRepository? _orderRepository;
  String? lastOrderError;
  OrderRepository get _orderStore => _orderRepository ??= OrderRepository(
    LocalOrderDataSource(
      orders: _orders,
      products: _products,
      isRemote: () => usesFirebase,
      onChanged: notifyListeners,
    ),
  );
  List<PharmacyOrder> get orders => List.unmodifiable(
    _orders.where(
      (order) => !usesFirebase && OrderPolicy.canRead(order, currentUser),
    ),
  );
  List<PharmacyOrder> get pendingOrders =>
      orders.where((order) => order.isPending).toList();
  List<PharmacyOrder> get approvedOrders =>
      orders.where((order) => order.isApproved).toList();
  List<PharmacyOrder> ordersForDriver(String driverId) => orders
      .where(
        (order) =>
            order.driverId == driverId ||
            order.attempts.any((attempt) => attempt.driverId == driverId),
      )
      .toList();
  int activeDeliveriesFor(String driverId) => orders
      .where(
        (order) =>
            order.driverId == driverId &&
            (order.isInTransit || order.isApproved),
      )
      .length;

  PharmacyOrder createOrder({
    required List<CartItem> items,
    String notes = '',
  }) {
    try {
      return _orderStore.confirm(
        actor: currentUser,
        pharmacy: pharmacy,
        items: items,
        notes: notes,
      );
    } on OrderStockException catch (error) {
      throw StockUnavailableException(error.name, error.available);
    }
  }

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
    lastOrderError = null;
    try {
      return _orderStore.execute(
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
      notifyListeners();
      return false;
    }
  }

  bool approveOrder(PharmacyOrder order) =>
      performOrderAction(order, OrderAction.approve);
  bool assignDelivery(PharmacyOrder order, AppUser driver) =>
      performOrderAction(order, OrderAction.assign, driver: driver);
  bool startDelivery(PharmacyOrder order) =>
      performOrderAction(order, OrderAction.dispatch);
  bool markDelivered(PharmacyOrder order) =>
      performOrderAction(order, OrderAction.deliver);
  bool markDeliveryFailed(
    PharmacyOrder order, {
    required String reason,
    String note = '',
  }) => performOrderAction(order, OrderAction.fail, reason: reason, note: note);
}
