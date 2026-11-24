import 'package:flutter/foundation.dart';

import '../domain/order_policy.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/order_lifecycle.dart';
import '../services/pharma_service.dart';

/// Estado de acciones de pedido. La autorización efectiva se repite en dominio.
class OrderViewModel extends ChangeNotifier {
  OrderViewModel({PharmaService? service})
    : service = service ?? PharmaService.instance;
  static final instance = OrderViewModel();
  final PharmaService service;
  bool busy = false;
  String? error;
  bool can(PharmacyOrder order, OrderAction action) =>
      !service.usesFirebase &&
      !order.remote &&
      OrderPolicy.rejection(order, service.currentUser, action) == null;
  bool act(
    PharmacyOrder order,
    OrderAction action, {
    String reason = '',
    String note = '',
    AppUser? driver,
    DateTime? scheduledFor,
  }) {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = service.performOrderAction(
        order,
        action,
        reason: reason,
        note: note,
        driver: driver,
        scheduledFor: scheduledFor,
      );
      if (!result) {
        error = service.lastOrderError ?? 'No se pudo realizar la operación.';
      }
      return result;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
