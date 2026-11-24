part of '../pharma_service.dart';

/// Estado y conversiones compartidos por los módulos del servicio.
abstract class _PharmaServiceState extends ChangeNotifier {
  final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // Regla de unicidad: el NIT se registra como identificador de reserva.
  final RegExp _nitPattern = RegExp(r'^[0-9]{7,15}$');

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

  PharmacyProfile get pharmacy => _currentPharmacy ?? PharmaService.demoProfile;

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

  FirebaseAuth get _auth => FirebaseEnvironment.auth;
  FirebaseFirestore get _db => FirebaseEnvironment.firestore;

  void _resetDemoData() {
    _products
      ..clear()
      ..addAll(buildSeedProducts());
    _orders
      ..clear()
      ..addAll(buildSeedOrders(PharmaService.demoProfile));
  }

  void _clearSession() {
    _currentUser = null;
    _currentPharmacy = null;
    _uid = null;
    _pharmacyId = null;
  }

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
}
