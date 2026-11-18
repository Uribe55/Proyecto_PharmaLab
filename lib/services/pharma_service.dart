import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/pharmacy.dart';
import '../models/product.dart';
import 'seed_data.dart';

/// Se lanza cuando se intenta confirmar un pedido sin stock suficiente (RF-09).
class StockUnavailableException implements Exception {
  const StockUnavailableException(this.productName, this.available);

  final String productName;
  final int available;

  @override
  String toString() =>
      'Stock insuficiente de $productName. Disponible: $available.';
}

class _Account {
  _Account({required this.password, required this.profile});

  final String password;
  PharmacyProfile profile;
}

/// Servicio central de catálogo, sesión y pedidos.
///
/// Mantiene la lógica fuera de los widgets (RNF-10 y RNF-11) para poder
/// reemplazar los datos locales por Firebase sin reescribir las pantallas.
class PharmaService extends ChangeNotifier {
  PharmaService._() {
    final profile = demoProfile;
    _accounts[demoEmail] = _Account(
      password: demoPassword,
      profile: profile,
    );
  }

  static final PharmaService instance = PharmaService._();

  static const String demoEmail = 'maria@laboratoriosanmartin.bo';
  static const String demoPassword = 'pharmalab123';

  static const PharmacyProfile demoProfile = PharmacyProfile(
    commercialName: 'Laboratorio San Martín',
    nit: '1023456789',
    responsible: 'María Fernández',
    phone: '+591 707-12345',
    address: 'Av. América Oeste #245, Cochabamba',
    email: demoEmail,
  );

  final List<Product> _products = buildSeedProducts();
  late final List<PharmacyOrder> _orders = buildSeedOrders(demoProfile);
  final Map<String, _Account> _accounts = {};

  PharmacyProfile? _currentUser;

  PharmacyProfile get pharmacy => _currentUser ?? demoProfile;

  bool get isLoggedIn => _currentUser != null;

  List<Product> get products => List.unmodifiable(_products);

  List<PharmacyOrder> get orders => List.unmodifiable(_orders);

  List<Product> get featuredProducts =>
      _products.where((product) => product.isFeatured).toList();

  int get productsInStock => _products.where((product) => product.isAvailable).length;

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  /// Devuelve `null` si el acceso fue correcto o un mensaje de error.
  String? login({required String email, required String password}) {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null) {
      return 'No encontramos una cuenta con ese correo electrónico.';
    }
    if (account.password != password) {
      return 'La contraseña no es correcta. Inténtalo nuevamente.';
    }

    _currentUser = account.profile;
    notifyListeners();
    return null;
  }

  /// Devuelve `null` si el registro fue correcto o un mensaje de error.
  String? register({
    required String commercialName,
    required String nit,
    required String responsible,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (_accounts.containsKey(normalizedEmail)) {
      return 'Ya existe una cuenta registrada con este correo electrónico.';
    }

    final profile = PharmacyProfile(
      commercialName: commercialName.trim(),
      nit: nit.trim(),
      responsible: responsible.trim(),
      phone: phone.trim(),
      address: address.trim(),
      email: normalizedEmail,
    );

    _accounts[normalizedEmail] = _Account(
      password: password,
      profile: profile,
    );
    _currentUser = profile;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  void updateAddress(String address) {
    final current = _currentUser;
    if (current == null) return;

    final updated = current.copyWith(address: address.trim());
    _currentUser = updated;
    final account = _accounts[updated.email.toLowerCase()];
    if (account != null) {
      account.profile = updated;
    }
    notifyListeners();
  }

  /// Confirma un pedido: valida stock, lo descuenta y genera el número único.
  PharmacyOrder createOrder({
    required List<CartItem> items,
    String notes = '',
  }) {
    if (items.isEmpty) {
      throw StateError('El carrito está vacío.');
    }

    // Primera pasada: validar todo antes de tocar el stock.
    for (final item in items) {
      final product = _products.firstWhere((p) => p.id == item.product.id);
      if (item.quantity <= 0 || item.quantity > product.stock) {
        throw StockUnavailableException(product.name, product.stock);
      }
    }

    // Segunda pasada: descontar stock (RF-08).
    for (final item in items) {
      final product = _products.firstWhere((p) => p.id == item.product.id);
      product.stock -= item.quantity;
    }

    final customer = pharmacy;
    final order = PharmacyOrder(
      number: _nextOrderNumber(),
      createdAt: DateTime.now(),
      status: OrderStatus.pendiente,
      pharmacyName: customer.commercialName,
      address: customer.address,
      contactName: customer.responsible,
      contactPhone: customer.phone,
      notes: notes.trim(),
      items: items
          .map(
            (item) => OrderLine(
              productId: item.product.id,
              name: item.product.name,
              brand: item.product.brand,
              presentation: item.product.presentation,
              unitPrice: item.product.price,
              quantity: item.quantity,
            ),
          )
          .toList(),
    );

    _orders.insert(0, order);
    notifyListeners();
    return order;
  }

  String _nextOrderNumber() {
    var maxSequence = 0;
    for (final order in _orders) {
      final sequence = int.tryParse(order.number.split('-').last) ?? 0;
      if (sequence > maxSequence) maxSequence = sequence;
    }

    final next = (maxSequence + 1).toString().padLeft(4, '0');
    return 'PL-${DateTime.now().year}-$next';
  }
}
