import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/datasources/firestore_order_data_source.dart';
import '../data/repositories/remote_order_repository.dart';
import '../models/order.dart';
import '../services/pharma_service.dart';

class OrderHistoryViewModel extends ChangeNotifier {
  static List<PharmacyOrder> selectOrders(
    Iterable<PharmacyOrder> source,
    String filter,
  ) {
    final orders = source
        .where(
          (order) => switch (filter) {
            'all' => true,
            'active' => !order.status.isFinal,
            'history' => order.status.isFinal,
            _ => order.status.name == filter,
          },
        )
        .toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  OrderHistoryViewModel({PharmaService? service, this.repository})
    : _service = service ?? PharmaService.instance {
    _service.addListener(_changed);
    _changed();
  }
  final PharmaService _service;
  RemoteOrderRepository? repository;
  StreamSubscription<List<PharmacyOrder>>? _subscription;
  String? _owner;
  String? _farm;
  int _limit = 50;
  bool _disposed = false;
  int _generation = 0;
  String? _paginationSession;
  bool get canLoadMore =>
      _service.usesFirebase &&
      repository is FirestoreOrderDataSource &&
      orders.length >= _limit;
  void loadMore() {
    if (!canLoadMore || loading) return;
    _limit += 50;
    _owner = null;
    _changed();
  }

  void retry() {
    _owner = null;
    _changed();
  }

  bool loading = false;
  String? error;
  List<PharmacyOrder> orders = [];

  void _changed() {
    if (!_service.usesFirebase) {
      _generation++;
      _subscription?.cancel();
      _subscription = null;
      _owner = null;
      _farm = null;
      loading = false;
      error = null;
      orders = [..._service.orders]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
      return;
    }
    final owner = _service.uid;
    final farm = _service.pharmacyId;
    final paginationSession = '$owner:$farm';
    final sameSession = _paginationSession == paginationSession;
    if (!sameSession) {
      _limit = 50;
      _paginationSession = paginationSession;
    }
    if (_owner == owner && _farm == farm) return;
    final generation = ++_generation;
    _subscription?.cancel();
    _owner = owner;
    _farm = farm;
    if (!sameSession) {
      orders = [];
    }
    loading = owner != null;
    error = null;
    if (owner != null && _service.pharmacyId != null) {
      repository ??= FirestoreOrderDataSource();
      final source = repository is FirestoreOrderDataSource
          ? (repository as FirestoreOrderDataSource).watchOwnOrders(
              limit: _limit,
            )
          : repository!.watchOwnOrders();
      _subscription = source.listen(
        (value) {
          if (_disposed ||
              generation != _generation ||
              _owner != owner ||
              _farm != farm) {
            return;
          }
          orders = [...value]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          loading = false;
          error = null;
          notifyListeners();
        },
        onError: (_) {
          if (_disposed ||
              generation != _generation ||
              _owner != owner ||
              _farm != farm) {
            return;
          }
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
    _disposed = true;
    _service.removeListener(_changed);
    _subscription?.cancel();
    super.dispose();
  }
}
