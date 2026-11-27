import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/pharma_service.dart';
import 'catalog_view_model.dart';

/// Coordina sesión y catálogo sobre el único carrito en memoria.
/// Los pedidos se conservan exclusivamente para la demostración local.
class CartViewModel extends ChangeNotifier {
  CartViewModel({
    CartService? service,
    PharmaService? session,
    CatalogViewModel? catalog,
  }) : _service = service ?? CartService.instance,
       _session = session ?? PharmaService.instance,
       _catalog = catalog ?? CatalogViewModel.instance {
    _sessionChanged();
    _service.addListener(notifyListeners);
    _session.addListener(_sessionChanged);
    _catalog.addListener(_catalogChanged);
    _catalogChanged();
  }
  static final instance = CartViewModel();
  final CartService _service;
  final PharmaService _session;
  final CatalogViewModel _catalog;
  List<CartItem> get items => _service.items;
  bool get isEmpty => _service.isEmpty;
  bool get isNotEmpty => _service.isNotEmpty;
  int get lineCount => _service.lineCount;
  int get totalUnits => _service.totalUnits;
  double get subtotal => _service.subtotal;
  bool get isRemote => _session.usesFirebase;
  bool get catalogReady => !isRemote || _catalog.ready;
  bool get canReview =>
      isNotEmpty &&
      catalogReady &&
      !_service.hasInventoryConflict &&
      items.every((item) => !item.needsAdjustment);
  bool get canConfirm => !isRemote && canReview;

  PharmacyOrder confirmDemoOrder({String notes = ''}) {
    if (!canConfirm) throw StateError('La confirmación no está disponible.');
    final order = _session.createOrder(items: List.of(items), notes: notes);
    clear();
    return order;
  }

  void _sessionChanged() {
    _service.bindSession(_session.currentUser?.id);
    notifyListeners();
  }

  void _catalogChanged() {
    if (isRemote && _catalog.ready) _service.reconcile(_catalog.products);
    notifyListeners();
  }

  Product? currentProduct(Product product) {
    if (!isRemote) return product;
    if (!_catalog.ready) return null;
    for (final latest in _catalog.products) {
      if (latest.cartKey == product.cartKey) return latest;
    }
    return null;
  }

  int quantityFor(Product product) => _service.quantityFor(product);
  int maximumFor(Product product) => _service.maximumFor(product);

  int remainingFor(Product product) {
    final latest = currentProduct(product);
    return latest == null ? 0 : _service.remainingFor(latest);
  }

  bool add(Product product, {int quantity = 1}) {
    final latest = currentProduct(product);
    return latest != null && _service.add(latest, quantity: quantity);
  }

  void setQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      remove(product);
      return;
    }
    final latest = currentProduct(product);
    if (latest == null || maximumFor(latest) < quantity) return;
    _service.setQuantity(latest, quantity);
  }

  void adjust(CartItem item) =>
      setQuantity(item.product, maximumFor(item.product));
  void remove(Product product) => _service.remove(product);
  void clear() => _service.clear();
  @override
  void dispose() {
    _service.removeListener(notifyListeners);
    _session.removeListener(_sessionChanged);
    _catalog.removeListener(_catalogChanged);
    super.dispose();
  }
}
