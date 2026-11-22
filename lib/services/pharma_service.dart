import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
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
  _Account({required this.password, required this.user, this.pharmacy});

  final String password;
  AppUser user;

  /// Solo las cuentas de farmacia cliente tienen perfil de farmacia.
  PharmacyProfile? pharmacy;
}

/// Servicio central de catálogo, sesión, pedidos y usuarios.
///
/// Mantiene la lógica fuera de los widgets (RNF-10 y RNF-11) para poder
/// reemplazar los datos locales por Firebase sin reescribir las pantallas.
class PharmaService extends ChangeNotifier {
  PharmaService._() {
    for (final user in demoUsers) {
      _accounts[user.email] = _Account(
        password: demoPassword,
        user: user,
        pharmacy: user.role == UserRole.cliente ? demoProfile : null,
      );
    }
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

  /// Cuentas de demostración para probar cada rol sin backend.
  static final List<AppUser> demoUsers = [
    AppUser(
      id: 'u-cliente',
      name: demoProfile.responsible,
      email: demoEmail,
      phone: demoProfile.phone,
      role: UserRole.cliente,
    ),
    ...buildSeedEmployees(),
  ];

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final List<Product> _products = buildSeedProducts();
  late final List<PharmacyOrder> _orders = buildSeedOrders(demoProfile);
  final Map<String, _Account> _accounts = {};

  AppUser? _currentUser;
  PharmacyProfile? _currentPharmacy;

  // ---------------------------------------------------------------- Sesión

  AppUser? get currentUser => _currentUser;

  UserRole get role => _currentUser?.role ?? UserRole.cliente;

  PharmacyProfile get pharmacy => _currentPharmacy ?? demoProfile;

  bool get isLoggedIn => _currentUser != null;

  /// Devuelve `null` si el acceso fue correcto o un mensaje de error.
  String? login({required String email, required String password}) {
    final normalized = email.trim().toLowerCase();
    final account = _accounts[normalized];
    if (account == null) {
      return 'No encontramos una cuenta con ese correo electrónico.';
    }
    if (account.password != password) {
      return 'La contraseña no es correcta. Inténtalo nuevamente.';
    }
    if (!account.user.active) {
      return 'Esta cuenta está desactivada. Contacta al administrador.';
    }

    _currentUser = account.user;
    _currentPharmacy = account.pharmacy;
    notifyListeners();
    return null;
  }

  /// Registra una farmacia cliente (RF-01).
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

    final user = AppUser(
      id: _newUserId(),
      name: profile.responsible,
      email: normalizedEmail,
      phone: profile.phone,
      role: UserRole.cliente,
    );

    _accounts[normalizedEmail] = _Account(
      password: password,
      user: user,
      pharmacy: profile,
    );
    _currentUser = user;
    _currentPharmacy = profile;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    _currentPharmacy = null;
    notifyListeners();
  }

  void updateAddress(String address) {
    final current = _currentPharmacy;
    if (current == null) return;

    final updated = current.copyWith(address: address.trim());
    _currentPharmacy = updated;
    final account = _accounts[updated.email.toLowerCase()];
    if (account != null) {
      account.pharmacy = updated;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- Catálogo

  List<Product> get products => List.unmodifiable(_products);

  List<Product> get featuredProducts =>
      _products.where((product) => product.isFeatured).toList();

  int get productsInStock =>
      _products.where((product) => product.isAvailable).length;

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  // -------------------------------------------------------------- Pedidos

  List<PharmacyOrder> get orders => List.unmodifiable(_orders);

  List<PharmacyOrder> get pendingOrders =>
      _orders.where((order) => order.isPending).toList();

  List<PharmacyOrder> get approvedOrders =>
      _orders.where((order) => order.isApproved).toList();

  List<PharmacyOrder> ordersForDriver(String driverId) =>
      _orders.where((order) => order.driverId == driverId).toList();

  int activeDeliveriesFor(String driverId) => _orders
      .where((order) => order.driverId == driverId && order.isInTransit)
      .length;

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

  /// Aprueba un pedido pendiente (RF-11).
  bool approveOrder(PharmacyOrder order) {
    if (!order.isPending) return false;
    order.status = OrderStatus.aprobado;
    notifyListeners();
    return true;
  }

  /// Asigna un pedido aprobado a un repartidor y lo pone en ruta (RF-12).
  bool assignDelivery(PharmacyOrder order, AppUser driver) {
    if (!order.canAssignDriver) return false;
    if (driver.role != UserRole.repartidor || !driver.active) return false;

    order
      ..driverId = driver.id
      ..driverName = driver.name
      ..status = OrderStatus.enRuta
      ..deliveredAt = null
      ..failureReason = null
      ..failureNote = null;
    notifyListeners();
    return true;
  }

  /// Marca el pedido como entregado con fecha y hora (RF-14).
  bool markDelivered(PharmacyOrder order) {
    if (!order.canDeliver) return false;
    order
      ..status = OrderStatus.entregado
      ..failureReason = null
      ..failureNote = null
      ..deliveredAt = DateTime.now();
    notifyListeners();
    return true;
  }

  /// Registra una entrega fallida con su motivo (RF-17).
  bool markDeliveryFailed(
    PharmacyOrder order, {
    required String reason,
    String note = '',
  }) {
    if (!order.canDeliver) return false;
    order
      ..status = OrderStatus.fallida
      ..failureReason = reason
      ..failureNote = note.trim()
      ..deliveredAt = DateTime.now();
    notifyListeners();
    return true;
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

  // -------------------------------------------------------------- Usuarios

  List<AppUser> get users =>
      _accounts.values.map((account) => account.user).toList();

  List<AppUser> get drivers => users
      .where((user) => user.role == UserRole.repartidor && user.active)
      .toList();

  int get activeUsers => users.where((user) => user.active).length;

  int get totalOrders => _orders.length;

  int get pendingOrdersCount =>
      _orders.where((order) => order.isPending).length;

  int get inTransitOrders => _orders.where((order) => order.isInTransit).length;

  int get completedDeliveries =>
      _orders.where((order) => order.status.isDelivered).length;

  /// Crea un usuario interno (vendedor, repartidor o administrador) (RF-19).
  String? createUser({
    required String name,
    required String email,
    required String phone,
    required UserRole role,
    required String password,
  }) {
    final normalized = email.trim().toLowerCase();

    if (name.trim().isEmpty) return 'Ingresa el nombre completo.';
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (phone.trim().isEmpty) return 'Ingresa un teléfono de contacto.';
    if (role == UserRole.cliente) {
      return 'Las cuentas de cliente se crean desde el registro de farmacia.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (_accounts.containsKey(normalized)) {
      return 'Ya existe una cuenta con ese correo electrónico.';
    }

    final user = AppUser(
      id: _newUserId(),
      name: name.trim(),
      email: normalized,
      phone: phone.trim(),
      role: role,
    );

    _accounts[normalized] = _Account(password: password, user: user);
    notifyListeners();
    return null;
  }

  /// Edita los datos de un usuario existente.
  String? updateUser({
    required AppUser user,
    required String name,
    required String email,
    required String phone,
    required UserRole role,
  }) {
    final normalized = email.trim().toLowerCase();
    final previousEmail = user.email.toLowerCase();
    final account = _accounts[previousEmail];
    if (account == null) return 'No encontramos la cuenta del usuario.';

    if (name.trim().isEmpty) return 'Ingresa el nombre completo.';
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (phone.trim().isEmpty) return 'Ingresa un teléfono de contacto.';
    if (normalized != previousEmail && _accounts.containsKey(normalized)) {
      return 'Ya existe otra cuenta con ese correo electrónico.';
    }
    if (account.pharmacy != null && role != UserRole.cliente) {
      return 'La cuenta de cliente no puede cambiar de rol.';
    }
    if (account.pharmacy == null && role == UserRole.cliente) {
      return 'Un usuario interno no puede convertirse en cliente.';
    }

    final updated = user.copyWith(
      name: name.trim(),
      email: normalized,
      phone: phone.trim(),
      role: role,
    );
    account.user = updated;

    final pharmacy = account.pharmacy;
    if (pharmacy != null) {
      account.pharmacy = pharmacy.copyWith(
        responsible: updated.name,
        email: normalized,
        phone: updated.phone,
      );
    }

    if (normalized != previousEmail) {
      _accounts.remove(previousEmail);
      _accounts[normalized] = account;
    }

    if (_currentUser?.id == user.id) {
      _currentUser = updated;
      _currentPharmacy = account.pharmacy;
    }

    notifyListeners();
    return null;
  }

  /// Activa o desactiva una cuenta (RF-19).
  String? setUserActive(AppUser user, bool active) {
    if (!active && _currentUser?.id == user.id) {
      return 'No puedes desactivar tu propia cuenta.';
    }

    final account = _accounts[user.email.toLowerCase()];
    if (account == null) return 'No encontramos la cuenta del usuario.';

    account.user = account.user.copyWith(active: active);
    if (_currentUser?.id == user.id) {
      _currentUser = account.user;
    }
    notifyListeners();
    return null;
  }

  String _newUserId() => 'u-${DateTime.now().microsecondsSinceEpoch}';
}
