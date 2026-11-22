import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Fase 1: autenticación y perfil reales; catálogo y pedidos aún locales.
class PharmaService extends ChangeNotifier {
  PharmaService._();

  static final PharmaService instance = PharmaService._();

  // Perfil de respaldo para widgets que consultan pharmacy sin sesión.
  // No es una cuenta de acceso y no contiene credenciales.
  static const String demoEmail = 'maria@laboratoriosanmartin.bo';
  static const PharmacyProfile demoProfile = PharmacyProfile(
    commercialName: 'Laboratorio San Martín',
    nit: '1023456789',
    responsible: 'María Fernández',
    phone: '+591 707-12345',
    address: 'Av. América Oeste #245, Cochabamba',
    email: demoEmail,
  );

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final List<Product> _products = buildSeedProducts();
  final List<PharmacyOrder> _orders = [];
  PharmacyProfile? _currentUser;
  String? _uid;
  String? _role;
  String? _pharmacyId;
  Future<void>? _pendingLogout;

  PharmacyProfile get pharmacy => _currentUser ?? demoProfile;
  bool get isLoggedIn => _currentUser != null;
  String? get uid => _uid;
  String? get role => _role;
  String? get pharmacyId => _pharmacyId;

  List<Product> get products => List.unmodifiable(_products);
  List<PharmacyOrder> get orders => List.unmodifiable(_orders);
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

  void _clearLocalSession() {
    _currentUser = null;
    _uid = null;
    _role = null;
    _pharmacyId = null;
    _orders.clear();
    _products
      ..clear()
      ..addAll(buildSeedProducts());
  }

  String _text(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value.trim() : '';
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-not-found':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      case 'network-request-failed':
        return 'No se pudo conectar. Revisa tu conexión a Internet.';
      case 'operation-not-allowed':
        return 'El inicio de sesión por correo y contraseña no está habilitado.';
      default:
        return 'No se pudo completar la autenticación (${e.code}).';
    }
  }

  /// Devuelve null si el acceso del cliente fue correcto.
  /// Los roles de empleados se verifican, pero aún no tienen navegación.
  Future<String?> login({required String email, required String password}) async {
    var success = false;
    try {
      final pendingLogout = _pendingLogout;
      if (pendingLogout != null) await pendingLogout;
      _clearLocalSession();
      if (_auth.currentUser != null) await _auth.signOut();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'No se pudo identificar la cuenta.';

      final account = await _db.collection('usuarios').doc(user.uid).get(
        const GetOptions(source: Source.server),
      );
      final accountData = account.data();
      if (accountData == null) {
        return 'La cuenta existe, pero falta su perfil en usuarios.';
      }
      if (accountData['estado'] != true) {
        return 'Tu perfil de PharmaLab está inactivo.';
      }
      final role = _text(accountData, 'rol');
      if (role != 'cliente') {
        if (const ['vendedor', 'repartidor', 'administrador'].contains(role)) {
          return 'Credenciales correctas. Rol: $role. '
              'Su interfaz todavía no está habilitada.';
        }
        return 'El perfil no tiene un rol válido.';
      }

      // Se utiliza el nombre real de la colección visto en tu consola.
      final pharmacies = await _db
          .collection('farmacia_cliente')
          .where('usuario_id', isEqualTo: user.uid)
          .limit(2)
          .get(const GetOptions(source: Source.server));
      if (pharmacies.docs.isEmpty) {
        return 'Tu cuenta no tiene una farmacia asociada.';
      }
      if (pharmacies.docs.length != 1) {
        return 'La cuenta tiene más de una farmacia asociada. '
            'Debe revisarse la vinculación.';
      }
      final pharmacyDoc = pharmacies.docs.single;
      final data = pharmacyDoc.data();
      if (data['estado'] != true) {
        return 'La farmacia asociada está inactiva.';
      }
      final name = _text(data, 'nombre_farmacia');
      if (name.isEmpty) return 'Falta el nombre de la farmacia.';
      final responsible = _text(data, 'responsable');
      _currentUser = PharmacyProfile(
        commercialName: name,
        nit: _text(data, 'nit'),
        responsible: responsible.isEmpty ? 'Sin registrar' : responsible,
        phone: _text(data, 'telefono'),
        address: _text(data, 'direccion_fiscal'),
        email: user.email ?? email.trim(),
      );
      _uid = user.uid;
      _role = role;
      _pharmacyId = pharmacyDoc.id;
      success = true;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Firestore denegó el acceso. Revisa las reglas de seguridad.';
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        return 'No se pudo consultar Firestore. Revisa tu conexión.';
      }
      return 'No se pudo consultar el perfil (${e.code}).';
    } catch (e) {
      debugPrint('Error de inicio de sesión: ${e.runtimeType}');
      return 'Ocurrió un error al iniciar sesión.';
    } finally {
      if (!success) {
        _clearLocalSession();
        try {
          await _auth.signOut();
        } catch (e) {
          debugPrint('No se pudo cerrar la sesión de Firebase: ${e.runtimeType}');
        }
        notifyListeners();
      }
    }
  }

  Future<String?> recoverPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      // Evita confirmar si un correo tiene cuenta registrada.
      if (e.code == 'user-not-found') return null;
      return _authError(e);
    } catch (_) {
      return 'No se pudo solicitar la recuperación de contraseña.';
    }
  }

  /// Se conserva la firma síncrona para no romper RegisterScreen todavía.
  /// No se guardan cuentas ni contraseñas locales.
  String? register({
    required String commercialName,
    required String nit,
    required String responsible,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) {
    return 'El registro real de farmacias se habilitará en la siguiente fase.';
  }

  Future<void> logout() async {
    _clearLocalSession();
    notifyListeners();
    final operation = _auth.signOut();
    _pendingLogout = operation;
    try {
      await operation;
    } catch (e) {
      debugPrint('Error al cerrar sesión: ${e.runtimeType}');
    } finally {
      if (identical(_pendingLogout, operation)) _pendingLogout = null;
    }
  }

  /// Solo modifica la dirección de la sesión de prueba, no Firestore.
  void updateAddress(String address) {
    final current = _currentUser;
    if (current == null) return;
    _currentUser = current.copyWith(address: address.trim());
    notifyListeners();
  }

  /// Pedido local de demostración. No escribe ni descuenta stock en Firestore.
  PharmacyOrder createOrder({
    required List<CartItem> items,
    String notes = '',
  }) {
    if (!isLoggedIn) throw StateError('No hay una sesión activa.');
    if (items.isEmpty) throw StateError('El carrito está vacío.');

    final requested = <String, int>{};
    for (final item in items) {
      if (item.quantity <= 0) {
        throw StateError('La cantidad debe ser mayor a cero.');
      }
      requested.update(item.product.id, (n) => n + item.quantity,
          ifAbsent: () => item.quantity);
    }
    for (final entry in requested.entries) {
      final product = _products.firstWhere((p) => p.id == entry.key);
      if (entry.value > product.stock) {
        throw StockUnavailableException(product.name, product.stock);
      }
    }
    for (final entry in requested.entries) {
      _products.firstWhere((p) => p.id == entry.key).stock -= entry.value;
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
      items: items.map((item) => OrderLine(
        productId: item.product.id,
        name: item.product.name,
        brand: item.product.brand,
        presentation: item.product.presentation,
        unitPrice: item.product.price,
        quantity: item.quantity,
      )).toList(),
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
