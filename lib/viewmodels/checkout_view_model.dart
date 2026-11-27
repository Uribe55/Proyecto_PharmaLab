import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/datasources/firestore_order_data_source.dart';
import '../data/datasources/pending_checkout_store.dart';
import '../data/repositories/remote_order_repository.dart';
import '../domain/spark_checkout.dart';
import '../models/delivery_address.dart';
import '../models/order.dart';
import '../services/pharma_service.dart';
import 'cart_view_model.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel({
    required this.repository,
    required this.store,
    required this.cart,
    required this.sessionUid,
  });
  // Coordinador único: sobrevive a la reapertura y bloquea dos pantallas simultáneas.
  static CheckoutViewModel? _instance;
  static CheckoutViewModel get instance => _instance ??= CheckoutViewModel(
    repository: FirestoreOrderDataSource(),
    store: SqlitePendingCheckoutStore(),
    cart: CartViewModel.instance,
    sessionUid: () => PharmaService.instance.uid,
  );
  final RemoteOrderRepository repository;
  final PendingCheckoutStore store;
  final CartViewModel cart;
  final String? Function() sessionUid;
  StreamSubscription<List<DeliveryAddress>>? _addressesSubscription;
  String? _owner;
  Map<String, dynamic>? _pending;
  final Map<String, int> reviewedPrices = {};
  List<DeliveryAddress> addresses = [];
  String? addressId, error;
  bool busy = false, ready = false, uncertain = false;
  bool get hasPending => _pending != null && _owner == sessionUid();
  String? get operationId => _pending?['operationId'] as String?;
  String? get pendingAddressId => _pending?['addressId'] as String?;
  String get pendingNotes => _pending?['notes'] as String? ?? '';
  List<Map<String, dynamic>> get pendingItems => [
    for (final item in _pending?['items'] as List? ?? [])
      Map<String, dynamic>.from(item as Map),
  ];
  double get pendingTotal => pendingItems.fold(
    0.0,
    (sum, item) =>
        sum +
        (item['quantity'] as num) * (item['expectedPriceCents'] as num) / 100,
  );
  bool get enabled => repository.confirmationEnabled;
  bool get supportsMultipleProducts =>
      repository is MultiOrderCapability &&
      (repository as MultiOrderCapability).supportsMultipleProducts;
  String get scopeMessage => supportsMultipleProducts
      ? 'Un pedido admite hasta 20 líneas, 10.000 unidades comerciales por línea y 100 lotes utilizados. Si se excede un límite, no se confirma ni divide el carrito.'
      : SparkCheckout.limitMessage;
  String? get scopeError => supportsMultipleProducts
      ? cart.items.length > 20 ||
                cart.items.any((item) => item.quantity > 10000)
            ? scopeMessage
            : null
      : cart.items.any((item) => item.product.presentationId != null)
      ? 'Las presentaciones con inventario base requieren el backend transaccional, disponible por ahora en emuladores.'
      : cart.items.length != 1
      ? SparkCheckout.limitMessage
      : cart.items.single.quantity > 1000
      ? 'El máximo es 1000 cajas por pedido.'
      : null;
  DeliveryAddress? get selectedAddress {
    for (final address in addresses) {
      if (address.id == addressId) return address;
    }
    return null;
  }

  int priceCents(String productId, double fallback) =>
      reviewedPrices[productId] ?? (fallback * 100).round();
  double get total => cart.items.fold(
    0.0,
    (sum, item) =>
        sum +
        priceCents(item.product.cartKey, item.product.price) *
            item.quantity /
            100,
  );
  bool get canConfirm =>
      enabled &&
      ready &&
      _owner == sessionUid() &&
      !busy &&
      (hasPending ||
          (scopeError == null && cart.canReview && selectedAddress != null));

  Future<void> initialize() async {
    final uid = sessionUid();
    if (uid == null || busy) return;
    if (_owner == uid && ready) return;
    busy = true;
    ready = false;
    error = null;
    notifyListeners();
    try {
      await _addressesSubscription?.cancel();
      _owner = uid;
      _pending = null;
      uncertain = false;
      addresses = [];
      addressId = null;
      reviewedPrices.clear();
      final pending = await store.read(uid);
      if (sessionUid() != uid) return;
      _pending = pending;
      uncertain = _pending != null;
      _addressesSubscription = repository.watchAddresses().listen(
        (value) {
          if (sessionUid() != _owner) return;
          addresses = value;
          if (selectedAddress == null) {
            addressId = value.isEmpty ? null : value.first.id;
          }
          notifyListeners();
        },
        onError: (_) {
          error = 'No se pudieron cargar las direcciones de entrega.';
          notifyListeners();
        },
      );
      ready = true;
    } catch (_) {
      error = 'No se pudo recuperar la operación pendiente. La confirmación permanece bloqueada.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void selectAddress(String? id) {
    if (busy || hasPending) return;
    addressId = id;
    notifyListeners();
  }

  Future<void> addAddress(String name, String address, String reference) async {
    if (busy || hasPending) return;
    await repository.addAddress(name, address, reference);
  }

  List<Map<String, dynamic>> _items() =>
      [
        for (final item in cart.items)
          {
            'productId': item.product.id,
            if (item.product.presentationId != null)
              'presentationId': item.product.presentationId,
            'quantity': item.quantity,
            'expectedPriceCents': priceCents(
              item.product.cartKey,
              item.product.price,
            ),
          },
      ]..sort((a, b) {
        final product = (a['productId'] as String).compareTo(
          b['productId'] as String,
        );
        return product != 0
            ? product
            : (a['presentationId'] as String? ?? '').compareTo(
                b['presentationId'] as String? ?? '',
              );
      });

  Future<PharmacyOrder?> confirm({
    String notes = '',
    bool consultOnly = false,
  }) async {
    if (busy || !ready || !enabled || _owner != sessionUid()) return null;
    if (!hasPending &&
        (!cart.canReview || selectedAddress == null || consultOnly)) {
      return null;
    }
    if (!hasPending && scopeError != null) {
      error = scopeError;
      notifyListeners();
      return null;
    }
    busy = true;
    error = null;
    notifyListeners();
    final uid = _owner!;
    final wasUncertain = uncertain;
    try {
      _pending ??= {
        'operationId': repository.newOperationId(),
        'addressId': addressId,
        'items': _items(),
        'notes': notes.trim(),
      };
      await store.write(uid, _pending); // Si falla no se envía nada.
      PharmacyOrder? order;
      if (uncertain || consultOnly) {
        order = await repository.result(operationId!);
        if (order == null && consultOnly) {
          error = 'Todavía no hay un pedido confirmado para esta operación. Puedes reintentar con el mismo ID.';
          return null;
        }
      }
      // Conserva el mismo payload ante reapertura, cambios de carrito y reintentos.
      order ??= await repository.confirm(_pending!);
      if (sessionUid() != uid) return null;
      if (order.fromCache || order.operationId != operationId) {
        throw StateError('Se requiere confirmación efectiva del servidor.');
      }
      await store.write(uid, null);
      if (sessionUid() != uid) return null;
      if (jsonEncode(_pending!['items']) == jsonEncode(_items())) cart.clear();
      _pending = null;
      uncertain = false;
      return order;
    } on RemoteOrderException catch (e) {
      error = e.message;
      if (e.definitive && !wasUncertain) {
        try {
          await store.write(uid, null);
        } catch (_) {
          uncertain = true;
          error = 'No se pudo actualizar el registro local. Se conserva el ID de operación para consultar su resultado.';
          return null;
        }
        _pending = null;
        reviewedPrices.addAll(e.prices);
        uncertain = false;
      } else {
        uncertain = true;
      }
      return null;
    } catch (_) {
      uncertain = hasPending;
      error = 'No se pudo verificar el resultado. Consulta la operación antes de volver a confirmar.';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _addressesSubscription?.cancel();
    super.dispose();
  }
}
