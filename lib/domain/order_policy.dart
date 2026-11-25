import '../models/app_user.dart';
import '../models/order.dart';
import '../models/order_lifecycle.dart';

/// Única política de autorización y transiciones; independiente de Flutter/Firebase.
class OrderPolicy {
  static bool manager(AppUser actor) =>
      actor.role == UserRole.vendedor || actor.role == UserRole.administrador;
  static bool owns(PharmacyOrder order, AppUser actor) =>
      actor.role == UserRole.cliente && order.customerId == actor.id;
  static bool driver(PharmacyOrder order, AppUser actor) =>
      actor.role == UserRole.repartidor && order.driverId == actor.id;
  static bool canRead(PharmacyOrder order, AppUser? actor) =>
      actor != null &&
      actor.active &&
      (manager(actor) ||
          owns(order, actor) ||
          driver(order, actor) ||
          (actor.role == UserRole.repartidor &&
              order.attempts.any((a) => a.driverId == actor.id)));

  static String? rejection(
    PharmacyOrder order,
    AppUser? actor,
    OrderAction action,
  ) {
    if (actor == null || !actor.active) return 'Necesitas una sesión activa.';
    if (!canRead(order, actor)) return 'No tienes acceso a este pedido.';
    if (order.status == OrderStatus.cancelado ||
        order.status == OrderStatus.entregado) {
      return 'El pedido está cerrado y no puede modificarse.';
    }
    final allowed = switch (action) {
      OrderAction.confirm => false,
      OrderAction.approve => manager(actor) && order.isPending,
      OrderAction.assign =>
        manager(actor) && order.isApproved && order.dispatchedAt == null,
      OrderAction.dispatch =>
        (manager(actor) || driver(order, actor)) &&
            order.isApproved &&
            order.driverId != null &&
            order.dispatchedAt == null,
      OrderAction.cancel =>
        owns(order, actor) && order.isPending && !order.hasBeenDispatched,
      OrderAction.requestCancellation =>
        owns(order, actor) &&
            order.isApproved &&
            !order.hasBeenDispatched &&
            order.pendingCancellation == null,
      OrderAction.acceptCancellation =>
        manager(actor) &&
            order.isApproved &&
            !order.hasBeenDispatched &&
            order.pendingCancellation != null,
      OrderAction.rejectCancellation =>
        manager(actor) && order.pendingCancellation != null,
      OrderAction.incident =>
        (driver(order, actor) || (owns(order, actor) && order.isInTransit)) &&
            order.isInTransit,
      OrderAction.fail ||
      OrderAction.deliver => driver(order, actor) && order.isInTransit,
      OrderAction.reschedule =>
        manager(actor) &&
            (order.status == OrderStatus.fallida || order.isRescheduled),
      OrderAction.coordinate || OrderAction.escalate =>
        manager(actor) &&
            (order.isInTransit ||
                order.status == OrderStatus.fallida ||
                order.isRescheduled ||
                order.isApproved),
    };
    return allowed
        ? null
        : 'Acción no permitida para este rol o estado del pedido.';
  }
}
