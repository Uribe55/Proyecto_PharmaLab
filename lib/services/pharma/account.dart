part of '../pharma_service.dart';

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
