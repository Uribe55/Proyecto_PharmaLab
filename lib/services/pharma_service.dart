import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

/// Cuenta local de demostración. Las cuentas reales viven en Firebase Auth y
/// solo se usan aquí como caché para las pantallas de gestión (RF-19).
class _Account {
  _Account({
    required this.user,
    this.password,
    this.pharmacy,
    this.remote = false,
  });

  /// Solo las cuentas locales de prueba guardan contraseña.
  final String? password;
  AppUser user;

  /// Solo las cuentas de farmacia cliente tienen perfil de farmacia.
  PharmacyProfile? pharmacy;

  /// Indica si el perfil proviene de la colección `usuarios` de Firestore.
  final bool remote;
}

/// Servicio central de catálogo, sesión, pedidos y usuarios.
///
/// Mantiene la lógica fuera de los widgets (RNF-10 y RNF-11). La autenticación
/// usa Firebase cuando la app está inicializada; si no hay Firebase (pruebas o
/// demostración sin conexión) se usan las cuentas locales de [demoUsers].
class PharmaService extends ChangeNotifier {
  PharmaService._() {
    _resetDemoData();
    for (final user in demoUsers) {
      _accounts[user.email.toLowerCase()] = _Account(
        password: demoPassword,
        user: user,
        pharmacy: user.role == UserRole.cliente ? demoProfile : null,
      );
    }
  }

  static final PharmaService instance = PharmaService._();

  // Perfil de respaldo para widgets que consultan pharmacy sin sesión.
  // No es una cuenta de acceso y no contiene credenciales.
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

  final List<Product> _products = [];
  final List<PharmacyOrder> _orders = [];
  final Map<String, _Account> _accounts = {};

  AppUser? _currentUser;
  PharmacyProfile? _currentPharmacy;
  String? _uid;
  String? _pharmacyId;
  Future<void>? _pendingLogout;

  // ---------------------------------------------------------------- Sesión

  AppUser? get currentUser => _currentUser;

  UserRole get role => _currentUser?.role ?? UserRole.cliente;

  PharmacyProfile get pharmacy => _currentPharmacy ?? demoProfile;

  bool get isLoggedIn => _currentUser != null;

  String? get uid => _uid;

  String? get pharmacyId => _pharmacyId;

  /// `true` cuando la app se inicializó con Firebase y puede autenticar y
  /// consultar Firestore. Las pruebas de widgets trabajan en modo local.
  bool get usesFirebase {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  void _resetDemoData() {
    _products
      ..clear()
      ..addAll(buildSeedProducts());
    _orders
      ..clear()
      ..addAll(buildSeedOrders(demoProfile));
  }

  void _clearSession() {
    _currentUser = null;
    _currentPharmacy = null;
    _uid = null;
    _pharmacyId = null;
  }

  /// Devuelve `null` si el acceso fue correcto o un mensaje de error.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (!usesFirebase) {
      return _loginLocal(email: email, password: password);
    }
    return _loginWithFirebase(email: email, password: password);
  }

  String? _loginLocal({required String email, required String password}) {
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

  Future<String?> _loginWithFirebase({
    required String email,
    required String password,
  }) async {
    var success = false;
    try {
      final pendingLogout = _pendingLogout;
      if (pendingLogout != null) await pendingLogout;
      _clearSession();
      if (_auth.currentUser != null) await _auth.signOut();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return 'No se pudo identificar la cuenta.';

      final account = await _db
          .collection('usuarios')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final accountData = account.data();
      if (accountData == null) {
        return 'La cuenta existe, pero falta su perfil en usuarios.';
      }
      if (!_isActive(accountData)) {
        return 'Tu perfil de PharmaLab está inactivo.';
      }

      final userRole = _roleFrom(accountData);
      if (userRole == null) {
        return 'El perfil no tiene un rol válido.';
      }

      final accountEmail = (user.email ?? email).trim();
      if (userRole == UserRole.cliente) {
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
        if (!_isActive(data)) {
          return 'La farmacia asociada está inactiva.';
        }
        final name = _pickText(data, const ['nombre_farmacia', 'nombre']);
        if (name.isEmpty) return 'Falta el nombre de la farmacia.';
        final responsible = _pickText(data, const [
          'responsable',
          'nombre_responsable',
        ]);
        final profile = PharmacyProfile(
          commercialName: name,
          nit: _pickText(data, const ['nit']),
          responsible: responsible.isEmpty ? 'Sin registrar' : responsible,
          phone: _pickText(data, const ['telefono', 'celular']),
          address: _pickText(data, const ['direccion_fiscal', 'direccion']),
          email: accountEmail,
        );
        _currentPharmacy = profile;
        _pharmacyId = pharmacyDoc.id;
        _currentUser = AppUser(
          id: user.uid,
          name: responsible.isEmpty ? name : responsible,
          email: accountEmail,
          phone: profile.phone,
          role: UserRole.cliente,
          active: true,
        );
      } else {
        _currentUser = _appUserFrom(
          user.uid,
          accountData,
          fallbackEmail: accountEmail,
          role: userRole,
        );
      }

      _uid = user.uid;
      final key = accountEmail.toLowerCase();
      _accounts[key] = _Account(
        user: _currentUser!,
        pharmacy: _currentPharmacy,
        remote: true,
      );
      _resetDemoData();
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
        _clearSession();
        try {
          await _auth.signOut();
        } catch (e) {
          debugPrint(
            'No se pudo cerrar la sesión de Firebase: ${e.runtimeType}',
          );
        }
        notifyListeners();
      }
    }
  }

  Future<String?> recoverPassword(String email) async {
    if (!usesFirebase) {
      return 'La recuperación de contraseña requiere conexión a Firebase.';
    }
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

  /// El registro real de farmacias se habilitará en una fase posterior.
  /// Se conserva la firma síncrona para no romper RegisterScreen todavía.
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
    _clearSession();
    notifyListeners();
    if (!usesFirebase) return;

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

  /// Actualiza la dirección de la farmacia en sesión y, si es posible,
  /// en el documento `farmacia_cliente` de Firestore.
  void updateAddress(String address) {
    final current = _currentPharmacy;
    if (current == null) return;

    final updated = current.copyWith(address: address.trim());
    _currentPharmacy = updated;

    final account = _accounts[updated.email.toLowerCase()];
    if (account != null) account.pharmacy = updated;

    final pharmacyId = _pharmacyId;
    if (usesFirebase && pharmacyId != null) {
      unawaited(
        _db
            .collection('farmacia_cliente')
            .doc(pharmacyId)
            .update({'direccion_fiscal': updated.address})
            .catchError((Object error) {
              debugPrint('No se pudo actualizar la dirección: $error');
            }),
      );
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
  ///
  /// Los pedidos siguen siendo locales: la colección de Firestore todavía no
  /// incluye pedidos, por lo que se conserva el flujo de demostración.
  PharmacyOrder createOrder({
    required List<CartItem> items,
    String notes = '',
  }) {
    if (!isLoggedIn) throw StateError('No hay una sesión activa.');
    if (items.isEmpty) throw StateError('El carrito está vacío.');

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

    // El repartidor guarda el correo institucional en lugar de datos de más.
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

  /// Carga los perfiles de la colección `usuarios` de Firestore (RF-19).
  ///
  /// Los documentos usan los campos `nombre`, `correo`, `telefono`, `rol` y
  /// `estado`. Se aceptan alias para tolerar datos ya cargados a mano.
  Future<void> refreshUsers() async {
    if (!usesFirebase) return;
    try {
      final snapshot = await _db
          .collection('usuarios')
          .get(const GetOptions(source: Source.server));
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userRole = _roleFrom(data);
        if (userRole == null) continue;
        final email = _pickText(data, const [
          'correo',
          'email',
          'correo_electronico',
        ]);
        if (email.isEmpty) continue;
        final user = _appUserFrom(
          doc.id,
          data,
          fallbackEmail: email,
          role: userRole,
        );
        _accounts[email.toLowerCase()] = _Account(
          user: user,
          remote: true,
          pharmacy: _currentUser?.id == user.id ? _currentPharmacy : null,
        );
      }
      notifyListeners();
    } on FirebaseException catch (e) {
      debugPrint('No se pudieron cargar los usuarios: ${e.code}');
    } catch (e) {
      debugPrint('No se pudieron cargar los usuarios: ${e.runtimeType}');
    }
  }

  /// Crea un usuario interno (vendedor, repartidor o administrador) (RF-19).
  ///
  /// El correo se genera con la convención institucional
  /// `nombre + inicial del apellido + @ + ven/rep/admin + .pharma.com`.
  Future<String?> createUser({
    required String name,
    required String phone,
    required UserRole role,
    required String password,
  }) async {
    if (name.trim().isEmpty) return 'Ingresa el nombre completo.';
    if (phone.trim().isEmpty) return 'Ingresa un teléfono de contacto.';
    if (role == UserRole.cliente) {
      return 'Las cuentas de cliente se crean desde el registro de farmacia.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    final baseEmail = AppUser.employeeEmail(name, role);
    if (baseEmail == null || !_emailPattern.hasMatch(baseEmail)) {
      return 'No se pudo generar el correo institucional del usuario.';
    }
    final email = _availableEmail(baseEmail);
    if (email == null) {
      return 'Ya existe una cuenta con el correo institucional generado '
          '($baseEmail).';
    }

    final user = AppUser(
      id: _newUserId(),
      name: _titleCase(name),
      email: email,
      phone: phone.trim(),
      role: role,
    );

    if (usesFirebase) {
      final authError = await _createFirebaseUser(user, password);
      if (authError != null) return authError;
    } else {
      _accounts[email] = _Account(password: password, user: user);
    }
    notifyListeners();
    return null;
  }

  /// Edita los datos de un usuario existente. El correo no cambia porque es
  /// la credencial de Firebase Auth; la inicial del apellido se fijó al crear.
  Future<String?> updateUser({
    required AppUser user,
    required String name,
    required String email,
    required String phone,
    required UserRole role,
  }) async {
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
      name: _titleCase(name),
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

    _pushUserProfile(updated);
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

    if (usesFirebase) {
      unawaited(
        _db
            .collection('usuarios')
            .doc(user.id)
            .update({'estado': active})
            .catchError((Object error) {
              debugPrint('No se pudo actualizar el estado del usuario: $error');
            }),
      );
    }

    notifyListeners();
    return null;
  }

  // --------------------------------------------------- Firebase (usuarios)

  /// Crea la cuenta de Firebase Auth sin cerrar la sesión del administrador.
  /// Se usa una instancia secundaria de Firebase que se elimina al terminar.
  Future<String?> _createFirebaseUser(AppUser user, String password) async {
    FirebaseApp? secondary;
    User? created;
    try {
      secondary = await Firebase.initializeApp(
        name: 'pharmalab-admin-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: user.email,
        password: password,
      );
      created = credential.user;
      if (created == null) return 'No se pudo crear la cuenta de acceso.';

      await _db.collection('usuarios').doc(created.uid).set({
        'nombre': user.name,
        'correo': user.email,
        'telefono': user.phone,
        'rol': user.role.name,
        'estado': true,
        'creado_en': FieldValue.serverTimestamp(),
      });

      // El identificador local pasa a ser el UID real de Firebase Auth.
      _accounts[user.email] = _Account(
        password: password,
        user: AppUser(
          id: created.uid,
          name: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
        ),
        remote: true,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authError(e);
    } on FirebaseException catch (e) {
      try {
        await created?.delete();
      } catch (_) {
        debugPrint('No se pudo revertir la cuenta de Auth.');
      }
      if (e.code == 'permission-denied') {
        return 'Firestore denegó el alta del usuario. Revisa las reglas.';
      }
      return 'No se pudo guardar el usuario (${e.code}).';
    } catch (e) {
      debugPrint('Error al crear el usuario: ${e.runtimeType}');
      return 'No se pudo crear el usuario.';
    } finally {
      if (secondary != null) {
        try {
          await secondary.delete();
        } catch (_) {
          debugPrint('No se pudo liberar la instancia secundaria de Firebase.');
        }
      }
    }
  }

  void _pushUserProfile(AppUser user) {
    if (!usesFirebase) return;
    unawaited(
      _db
          .collection('usuarios')
          .doc(user.id)
          .update({
            'nombre': user.name,
            'telefono': user.phone,
            'rol': user.role.name,
          })
          .catchError((Object error) {
            debugPrint('No se pudo actualizar el perfil del usuario: $error');
          }),
    );
  }

  // --------------------------------------------------------------- Ayudas

  AppUser _appUserFrom(
    String id,
    Map<String, dynamic> data, {
    required String fallbackEmail,
    required UserRole role,
  }) {
    final name = _pickText(data, const [
      'nombre',
      'nombre_completo',
      'nombres',
      'name',
    ]);
    final email = _pickText(data, const [
      'correo',
      'email',
      'correo_electronico',
    ]);
    return AppUser(
      id: id,
      name: name.isEmpty ? fallbackEmail : name,
      email: email.isEmpty ? fallbackEmail : email,
      phone: _pickText(data, const ['telefono', 'celular', 'phone']),
      role: role,
      active: _isActive(data),
    );
  }

  UserRole? _roleFrom(Map<String, dynamic> data) {
    final raw = _pickText(data, const ['rol', 'role', 'tipo_usuario']);
    return switch (raw.toLowerCase()) {
      'cliente' || 'farmacia' => UserRole.cliente,
      'vendedor' => UserRole.vendedor,
      'repartidor' => UserRole.repartidor,
      'administrador' || 'admin' => UserRole.administrador,
      _ => null,
    };
  }

  bool _isActive(Map<String, dynamic> data) {
    final value = data['estado'] ?? data['activo'] ?? data['active'];
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'activo' ||
          normalized == 'activa' ||
          normalized == '1';
    }
    return true;
  }

  String _pickText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Nombre legible de una cuenta a partir del correo cuando falta el nombre.
  String? _availableEmail(String base) {
    if (!_accounts.containsKey(base)) return base;
    final at = base.indexOf('@');
    final local = base.substring(0, at);
    final domain = base.substring(at);
    for (var suffix = 2; suffix < 100; suffix++) {
      final candidate = '$local$suffix$domain';
      if (!_accounts.containsKey(candidate)) return candidate;
    }
    return null;
  }

  String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
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
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo electrónico.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
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

  String _newUserId() => 'u-${DateTime.now().microsecondsSinceEpoch}';
}
