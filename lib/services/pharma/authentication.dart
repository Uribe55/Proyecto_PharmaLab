part of '../pharma_service.dart';

/// Inicio y cierre de sesión, recuperación y perfil de la farmacia.
mixin _PharmaAuthentication on _PharmaServiceState {
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
      // El login real no carga semillas ni pedidos de demostración.
      _products.clear();
      _orders.clear();
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
}
