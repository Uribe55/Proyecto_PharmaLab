import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/order_lifecycle.dart';
import '../services/pharma_service.dart';
import '../services/sync_service.dart';

/// Coordina acciones de reparto y su cola local sin cambiar las reglas del dominio.
class DeliveryViewModel extends ChangeNotifier {
  DeliveryViewModel({PharmaService? service, SyncService? sync})
    : service = service ?? PharmaService.instance,
      sync = sync ?? SyncService.instance;
  static final instance = DeliveryViewModel();
  final PharmaService service;
  final SyncService sync;
  String? error;
  bool record(
    PharmacyOrder order,
    OrderAction action, {
    String reason = '',
    String note = '',
  }) {
    final queued =
        sync.isOffline &&
        {
          OrderAction.deliver,
          OrderAction.fail,
          OrderAction.incident,
        }.contains(action);
    final ok = queued
        ? sync.queueAction(order, action, reason: reason, note: note)
        : service.performOrderAction(order, action, reason: reason, note: note);
    error = ok
        ? null
        : queued
        ? sync.lastError
        : service.lastOrderError;
    notifyListeners();
    return ok;
  }

  bool start(PharmacyOrder order) => record(order, OrderAction.dispatch);
  bool deliver(PharmacyOrder order) => record(order, OrderAction.deliver);
  bool fail(PharmacyOrder order, {required String reason, String note = ''}) =>
      record(order, OrderAction.fail, reason: reason, note: note);
}
