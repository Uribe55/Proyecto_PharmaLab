import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/dashboard_metrics.dart';
import '../models/dashboard_models.dart';
import '../services/dashboard_repository.dart';
import '../services/pharma_service.dart';

/// ViewModel del dashboard administrativo.
///
/// Mantiene dos fuentes de datos: los pedidos en tiempo real (Firestore o
/// pedidos locales) y el inventario (lotes/productos). La vista solo consume
/// las propiedades ya procesadas.
class AdminDashboardViewModel extends ChangeNotifier {
  AdminDashboardViewModel({
    DashboardRepository? repository,
    DateTime Function()? clock,
  }) : _repository = repository ?? DashboardRepository(),
       _clock = clock ?? DateTime.now;

  final DashboardRepository _repository;
  final DateTime Function() _clock;

  StreamSubscription<DashboardFeed>? _ordersSubscription;
  bool _disposed = false;
  bool _initialized = false;
  int _inventoryRequest = 0;

  List<DashboardOrder> _orders = const [];
  DashboardInventory _inventory = const DashboardInventory.loading();
  DashboardOrigin _origin = DashboardOrigin.loading;
  bool _loadingOrders = true;
  bool _loadingInventory = true;
  String? _ordersError;
  String? _inventoryError;
  DateTime? _updatedAt;
  DashboardPeriod _period = DashboardPeriod.anio;
  DateRange? _customRange;

  List<DashboardOrder> get orders => _orders;

  DashboardInventory get inventory => _inventory;

  DashboardOrigin get origin => _origin;

  bool get loadingOrders => _loadingOrders;

  bool get loadingInventory => _loadingInventory;

  String? get ordersError => _ordersError;

  String? get inventoryError => _inventoryError;

  DateTime? get updatedAt => _updatedAt;

  DashboardPeriod get period => _period;

  DateRange? get customRange => _customRange;

  int get lowStockThreshold => _repository.lowStockThreshold;

  DateTime get now => _clock();

  DateRange get range => DateRange.resolve(_period, now, custom: _customRange);

  bool get isFirestore => _origin == DashboardOrigin.firestore;

  bool get isLocalFallback => _origin == DashboardOrigin.localFallback;

  bool get hasPermissionIssue =>
      _origin == DashboardOrigin.permissionDenied ||
      _inventory.isPermissionDenied;

  bool get hasOrdersError =>
      _origin == DashboardOrigin.error || _ordersError != null;

  bool get isLoading => _loadingOrders || _loadingInventory;

  DashboardMetrics get metrics => DashboardMetrics.compute(
    orders: _orders,
    inventory: _inventory,
    period: range,
    now: now,
    lowStockThreshold: lowStockThreshold,
    driverNames: {
      for (final user in PharmaService.instance.users) user.id: user.name,
    },
  );

  void init() {
    if (_initialized || _disposed) return;
    _initialized = true;
    _subscribeOrders();
    unawaited(loadInventory());
  }

  void _subscribeOrders() {
    unawaited(_ordersSubscription?.cancel());
    _loadingOrders = true;
    _ordersSubscription = _repository.watchOrders().listen(
      (feed) {
        if (_disposed) return;
        _orders = feed.orders;
        _origin = feed.origin;
        _loadingOrders = false;
        _ordersError = feed.message;
        _updatedAt = feed.updatedAt;
        notifyListeners();
      },
      onError: (Object error) {
        if (_disposed) return;
        _origin = DashboardOrigin.error;
        _loadingOrders = false;
        _ordersError = 'No se pudieron cargar los pedidos. Revisa la conexión.';
        debugPrint('Error de pedidos en el dashboard: $error');
        notifyListeners();
      },
    );
  }

  Future<void> loadInventory() async {
    final request = ++_inventoryRequest;
    _loadingInventory = true;
    _inventoryError = null;
    notifyListeners();

    final result = await _repository.loadInventory();
    if (_disposed || request != _inventoryRequest) return;

    _inventory = result;
    _loadingInventory = false;
    _inventoryError = result.error;
    notifyListeners();
  }

  void setPeriod(DashboardPeriod value) {
    if (value == DashboardPeriod.personalizado && _customRange == null) {
      return;
    }
    if (_period == value) return;
    _period = value;
    notifyListeners();
  }

  void setCustomRange(DateRange value) {
    _customRange = value;
    _period = DashboardPeriod.personalizado;
    notifyListeners();
  }

  Future<void> refresh() async {
    _ordersError = null;
    _loadingOrders = true;
    notifyListeners();
    _subscribeOrders();
    await loadInventory();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_ordersSubscription?.cancel());
    super.dispose();
  }
}
