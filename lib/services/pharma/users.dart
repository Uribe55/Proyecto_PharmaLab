part of '../pharma_service.dart';

/// Gestión de usuarios internos y sincronización de sus perfiles.
mixin _PharmaUsers on _PharmaServiceState {
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
