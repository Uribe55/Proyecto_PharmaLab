import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/datasources/firestore_order_data_source.dart';
import '../data/repositories/remote_order_repository.dart';
import '../models/order.dart';
import '../services/pharma_service.dart';

class OrderHistoryViewModel extends ChangeNotifier {
  OrderHistoryViewModel({PharmaService? service, this.repository})
    : _service = service ?? PharmaService.instance {
    _service.addListener(_changed);
    _changed();
  }
  final PharmaService _service;
  RemoteOrderRepository? repository;
  StreamSubscription<List<PharmacyOrder>>? _subscription;
  String? _owner;
  bool loading = false;
  String? error;
  List<PharmacyOrder> orders = [];

  void _changed() {
    if (!_service.usesFirebase) {
      orders = _service.orders;
      notifyListeners();
      return;
    }
    final owner = _service.uid;
    if (_owner == owner) return;
    _subscription?.cancel();
    _owner = owner;
    orders = [];
    loading = owner != null;
    error = null;
    if (owner != null && _service.pharmacyId != null) {
      repository ??= FirestoreOrderDataSource();
      _subscription = repository!.watchOwnOrders().listen(
        (value) {
          if (_owner != owner) return;
          orders = value;
          loading = false;
          error = null;
          notifyListeners();
        },
        onError: (_) {
          if (_owner != owner) return;
          loading = false;
          error = 'No se pudieron consultar los pedidos. Revisa la conexión y los permisos.';
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    _subscription?.cancel();
    super.dispose();
  }
}
