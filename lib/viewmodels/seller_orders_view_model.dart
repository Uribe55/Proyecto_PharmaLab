import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/staff_order_repository.dart';
import '../models/order.dart';

/// Estado remoto del vendedor. La sesión y el stream son inyectables.
class SellerOrdersViewModel extends ChangeNotifier {
  SellerOrdersViewModel({
    required this.repository,
    required this.sessionChanges,
    required this.authorizedUid,
  }) {
    sessionChanges.addListener(_sessionChanged);
    _sessionChanged();
  }
  final StaffOrderRepository repository;
  final Listenable sessionChanges;
  final String? Function() authorizedUid;
  StreamSubscription<StaffOrderFeed>? _subscription;
  String? _uid;
  int _generation = 0;
  bool _baseline = false;
  bool _disposed = false;
  final Set<String> _seen = {};
  List<PharmacyOrder> orders = [];
  bool loading = false, fromCache = false;
  String? error;
  int notificationVersion = 0, newPendingCount = 0;
  int get pendingCount => orders.where((o) => o.isPending).length;

  void _sessionChanged() {
    final uid = authorizedUid();
    if (uid == _uid) return;
    _uid = uid;
    final generation = ++_generation;
    _subscription?.cancel();
    _subscription = null;
    orders = [];
    error = null;
    loading = uid != null;
    fromCache = false;
    _baseline = false;
    _seen.clear();
    newPendingCount = 0;
    if (uid != null) {
      try {
        _subscription = repository.watchOrders().listen(
          (feed) {
            if (_disposed || generation != _generation) return;
            orders = feed.orders;
            loading = false;
            error = null;
            fromCache = feed.fromCache;
            if (!feed.fromCache) {
              final fresh = orders
                  .where(
                    (o) =>
                        o.isPending &&
                        !_seen.contains(o.documentId ?? o.number),
                  )
                  .length;
              if (_baseline && fresh > 0) {
                newPendingCount = fresh;
                notificationVersion++;
              }
              _seen.addAll(orders.map((o) => o.documentId ?? o.number));
              _baseline = true;
            }
            notifyListeners();
          },
          onError: (_) {
            if (_disposed || generation != _generation) return;
            orders = [];
            loading = false;
            error = 'No se pudieron consultar los pedidos reales. Revisa tu conexión y permisos.';
            notifyListeners();
          },
        );
      } catch (_) {
        loading = false;
        error = 'La sesión no permite consultar pedidos.';
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    sessionChanges.removeListener(_sessionChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
