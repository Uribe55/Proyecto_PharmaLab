part of '../pharma_service.dart';

/// Gestión de usuarios internos y sincronización de sus perfiles.
mixin _PharmaUsers on _PharmaServiceState {
  List<AppUser> get users => _accounts.values
      .where((account) => account.remote == usesFirebase)
      .map((account) => account.user)
      .toList();

  List<AppUser> get drivers => users
      .where((user) => user.role == UserRole.repartidor && user.active)
      .toList();

  int get activeUsers => users.where((user) => user.active).length;

  int get totalOrders => usesFirebase ? 0 : _orders.length;

  int get pendingOrdersCount =>
      usesFirebase ? 0 : _orders.where((order) => order.isPending).length;

  int get inTransitOrders =>
      usesFirebase ? 0 : _orders.where((order) => order.isInTransit).length;

  int get completedDeliveries => usesFirebase
      ? 0
      : _orders.where((order) => order.status.isDelivered).length;

  String? usersError;
  bool loadingUsers = false;

  /// Carga los perfiles de la colección `usuarios` de Firestore (RF-19).
  ///
  /// Los documentos usan los campos `nombre`, `correo`, `telefono`, `rol` y
  /// `estado`. Se aceptan alias para tolerar datos ya cargados a mano.
  Future<void> refreshUsers() async {
    if (!usesFirebase) return;
    loadingUsers = true;
    usersError = null;
    try {
      final snapshot = await _db
          .collection('usuarios')
          .get(const GetOptions(source: Source.server));
      _accounts.removeWhere((_, account) => account.remote);
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
    } on FirebaseException catch (e) {
      usersError = e.code == 'permission-denied'
          ? 'No tienes permisos para consultar los usuarios reales.'
          : 'No se pudieron cargar los usuarios reales. Revisa la conexión.';
      debugPrint('No se pudieron cargar los usuarios: ${e.code}');
    } catch (e) {
      usersError = 'No se pudieron cargar los usuarios reales.';
      debugPrint('No se pudieron cargar los usuarios: ${e.runtimeType}');
    } finally {
      loadingUsers = false;
      notifyListeners();
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
    if (role == UserRole.administrador) {
      return 'Las cuentas administrador no se crean desde este panel.';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    if (usesFirebase) {
      return 'Utiliza Gestionar empleados EMP### para registrar personal.';
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
      return 'Utiliza Gestionar empleados EMP###.';
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
    if (usesFirebase &&
        user.role != UserRole.cliente &&
        user.role != UserRole.administrador) {
      return 'Edita el personal desde Gestionar empleados EMP###.';
    }
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
    if (role == UserRole.administrador && user.role != UserRole.administrador) {
      return 'No se puede asignar el rol administrador desde este panel.';
    }
    if (user.role == UserRole.administrador && role != UserRole.administrador) {
      return 'La cuenta administrador no puede cambiar de rol.';
    }

    final updated = user.copyWith(
      name: _titleCase(name),
      email: normalized,
      phone: phone.trim(),
      role: role,
    );
    final profileError = await _pushUserProfile(updated);
    if (profileError != null) return profileError;
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

  /// Permite al cliente o al repartidor editar su nombre, teléfono y
  /// dirección desde la pantalla de cuenta (RF-01).
  ///
  /// El cambio se aplica de inmediato en la sesión y se persiste en
  /// `usuarios`; para el cliente también se sincroniza su farmacia.
  Future<String?> updateOwnProfile({
    required String name,
    required String phone,
    required String address,
  }) async {
    final user = _currentUser;
    if (user == null) return 'No hay una sesión activa.';
    if (name.trim().isEmpty) return 'Ingresa el nombre completo.';
    if (phone.trim().isEmpty) return 'Ingresa un teléfono de contacto.';

    final account = _accounts[user.email.toLowerCase()];
    if (account == null) return 'No encontramos la cuenta del usuario.';

    final updated = user.copyWith(
      name: _titleCase(name),
      phone: phone.trim(),
      address: address.trim(),
    );
    final pharmacy = account.pharmacy;
    if (usesFirebase) {
      try {
        final batch = _db.batch();
        final employees = user.role == UserRole.cliente
            ? null
            : await _db
                  .collection('empleado')
                  .where('usuario_id', isEqualTo: user.id)
                  .get(const GetOptions(source: Source.server));
        if (employees != null && employees.docs.length > 1) {
          return 'El vínculo del empleado no es único.';
        }
        final employee = employees?.docs.isNotEmpty == true
            ? employees!.docs.single
            : null;
        if (employee != null) {
          batch.update(employee.reference, {'telefono': updated.phone});
        }
        batch.update(_db.collection('usuarios').doc(updated.id), {
          'nombre': updated.name,
          if (employee == null) 'telefono': updated.phone,
          'direccion': updated.address,
        });
        final pharmacyId = _pharmacyId;
        if (pharmacyId != null) {
          batch.update(_db.collection('farmacia_cliente').doc(pharmacyId), {
            'responsable': updated.name,
            'telefono': updated.phone,
            'direccion_fiscal': updated.address,
          });
        }
        await batch.commit();
      } on FirebaseException catch (error) {
        return 'No se guardó el perfil en Firestore (${error.code}).';
      } catch (_) {
        return 'No se pudo guardar el perfil.';
      }
    }
    account.user = updated;
    if (pharmacy != null) {
      account.pharmacy = pharmacy.copyWith(
        responsible: updated.name,
        phone: updated.phone,
        address: updated.address,
      );
    }
    _currentUser = updated;
    _currentPharmacy = account.pharmacy;
    notifyListeners();
    return null;
  }

  /// Actualiza el estado de cuenta simulado del cliente (RF-07).
  ///
  /// En Firebase el campo `tiene_deuda_vencida` es de solo lectura para el
  /// cliente: las reglas impiden que lo modifique. La simulación se aplica
  /// únicamente en el modo local de demostración.
  void setDebtStatus({required bool hasDebt}) {
    final user = _currentUser;
    if (user == null) return;
    if (usesFirebase) return;
    final updated = user.copyWith(tieneDeudaVencida: hasDebt);
    _currentUser = updated;
    final account = _accounts[user.email.toLowerCase()];
    if (account != null) account.user = updated;

    if (usesFirebase) {
      debugPrint(
        'tiene_deuda_vencida es administrado por el servidor; no se escribe '
        'desde la sesión del cliente.',
      );
    }
    notifyListeners();
  }

  /// Activa o desactiva una cuenta (RF-19).
  ///
  /// Devuelve `null` solo cuando Firestore confirmó la escritura. En Firebase
  /// el estado local no se modifica si la operación falla.
  Future<String?> setUserActive(AppUser user, bool active) async {
    if (usesFirebase &&
        (user.role == UserRole.vendedor || user.role == UserRole.repartidor)) {
      return 'Cambia el estado desde Gestionar empleados EMP###.';
    }
    if (!active && _currentUser?.id == user.id) {
      return 'No puedes desactivar tu propia cuenta.';
    }

    final account = _accounts[user.email.toLowerCase()];
    if (account == null) return 'No encontramos la cuenta del usuario.';

    if (usesFirebase) {
      try {
        await _db.collection('usuarios').doc(user.id).update({
          'estado': active,
        });
      } on FirebaseException catch (error) {
        return error.code == 'permission-denied'
            ? 'Firestore denegó el cambio de estado. Revisa las reglas y que '
                  'tu cuenta siga siendo administrador activo.'
            : 'No se pudo actualizar el estado (${error.code}).';
      } catch (error) {
        debugPrint('No se pudo actualizar el estado del usuario: $error');
        return 'No se pudo actualizar el estado del usuario.';
      }
    }

    account.user = account.user.copyWith(active: active);
    if (_currentUser?.id == user.id) {
      _currentUser = account.user;
    }
    notifyListeners();
    return null;
  }

  // --------------------------------------------------- Firebase (usuarios)

  /// Crea la cuenta de Firebase Auth sin cerrar la sesión del administrador.
  /// Se usa una instancia secundaria de Firebase que se elimina al terminar.
  Future<({String? uid, String? error})> createStaffAccess(
    String email,
    String password,
  ) async {
    if (_currentUser?.role != UserRole.administrador ||
        _currentUser?.active != true) {
      return (uid: null, error: 'Se requiere administrador activo.');
    }
    FirebaseApp? secondary;
    try {
      final admin = await _db
          .collection('usuarios')
          .doc(_auth.currentUser!.uid)
          .get(const GetOptions(source: Source.server));
      if (admin.data()?['rol'] != 'administrador' ||
          admin.data()?['estado'] != true) {
        return (
          uid: null,
          error: 'Se requiere administrador activo en Firestore.',
        );
      }
      secondary = await Firebase.initializeApp(
        name: 'pharmalab-admin-${DateTime.now().microsecondsSinceEpoch}',
        options: _auth.app.options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
      if (FirebaseEnvironment.emulatorOrdersEnabled) {
        await secondaryAuth.useAuthEmulator(
          FirebaseEnvironment.emulatorHost!,
          9099,
          automaticHostMapping: false,
        );
      }
      UserCredential credential;
      try {
        credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        // Recovery after restart proves the real UID using existing credentials.
        credential = await secondaryAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      return (
        uid: credential.user?.uid,
        error: credential.user == null
            ? 'Authentication no devolvió UID.'
            : null,
      );
    } on FirebaseAuthException catch (error) {
      return (uid: null, error: _authError(error));
    } catch (error) {
      return (uid: null, error: 'No se pudo crear la cuenta de acceso.');
    } finally {
      if (secondary != null) {
        try {
          await secondary.delete();
        } catch (_) {
          debugPrint('No se pudo liberar Firebase secundario.');
        }
      }
    }
  }

  Future<String?> _pushUserProfile(AppUser user) async {
    if (!usesFirebase) return null;
    try {
      await _db.collection('usuarios').doc(user.id).update({
        'nombre': user.name,
        'telefono': user.phone,
        'direccion': user.address,
        'rol': user.role.name,
      });
      return null;
    } on FirebaseException catch (error) {
      debugPrint('No se pudo actualizar el perfil del usuario: ${error.code}');
      return error.code == 'permission-denied'
          ? 'Firestore denegó la actualización del perfil. Revisa las reglas.'
          : 'No se pudo guardar el perfil en Firestore (${error.code}).';
    } catch (error) {
      debugPrint('No se pudo actualizar el perfil del usuario: $error');
      return 'No se pudo guardar el perfil en Firestore.';
    }
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

  String _newUserId() => 'u-${DateTime.now().microsecondsSinceEpoch}';
}
