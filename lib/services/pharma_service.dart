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
import 'firebase_environment.dart';
import '../data/datasources/local_order_data_source.dart';
import '../data/repositories/order_repository.dart';
import '../domain/order_policy.dart';
import '../models/order_lifecycle.dart';

part 'pharma/account.dart';
part 'pharma/stock_unavailable_exception.dart';
part 'pharma/service_state.dart';
part 'pharma/authentication.dart';
part 'pharma/pharmacy_registration.dart';
part 'pharma/catalog.dart';
part 'pharma/orders.dart';
part 'pharma/users.dart';

/// Punto de acceso al servicio. Cada módulo mantiene una responsabilidad.
/// Los archivos part comparten el estado privado sin exponerlo a las pantallas.
class PharmaService extends _PharmaServiceState
    with
        _PharmaAuthentication,
        _PharmaRegistration,
        _PharmaCatalog,
        _PharmaOrders,
        _PharmaUsers {
  PharmaService._() {
    if (usesFirebase) return;
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
}
