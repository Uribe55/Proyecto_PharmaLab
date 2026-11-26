import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/logistics_repository.dart';
import '../models/order.dart';

class LogisticsViewModel extends ChangeNotifier {
  LogisticsViewModel(this.repository);
  final LogisticsRepository repository;
  bool busy = false;
  String? error;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (e) {
      error =
          'No se pudo guardar en Firestore. Verifica conexión, permisos y estado. $e';
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> assign(PharmacyOrder order, String employee) =>
      _run(() => repository.assign(order, employee));
  Future<bool> transition(
    DeliveryRecord record,
    String state, {
    String reason = '',
    String note = '',
  }) => _run(
    () => repository.transition(record, state, reason: reason, note: note),
  );
}
