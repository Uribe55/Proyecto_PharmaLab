part of '../pharma_service.dart';

/// Registro atómico de la farmacia, su perfil y la reserva del NIT.
mixin _PharmaRegistration on _PharmaServiceState {
  /// Los documentos de `usuarios` continúan utilizando el UID de Auth.
  /// Las farmacias usan IDs legibles y consecutivos: FARM001, FARM002, FARM003...
  ///
  /// El contador debe existir previamente en:
  /// `configuracion/contadores_farmacia` con `ultimo_numero: 2` si
  /// actualmente existen FARM001 y FARM002.
  Future<String?> register({
    required String commercialName,
    required String nit,
    required String responsible,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) async {
    if (!usesFirebase) {
      return 'El registro requiere una conexión a Firebase.';
    }

    final name = commercialName.trim();
    final taxId = nit.trim();
    final contact = responsible.trim();
    final phoneNumber = phone.trim();
    final streetAddress = address.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (name.isEmpty ||
        !_nitPattern.hasMatch(taxId) ||
        contact.isEmpty ||
        phoneNumber.isEmpty ||
        streetAddress.isEmpty ||
        !_emailPattern.hasMatch(normalizedEmail) ||
        password.length < 6) {
      return 'Revisa los datos del formulario antes de registrarte.';
    }

    User? createdUser;
    var completed = false;
    try {
      final pendingLogout = _pendingLogout;
      if (pendingLogout != null) await pendingLogout;
      _clearSession();
      if (_auth.currentUser != null) await _auth.signOut();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) return 'No se pudo crear la cuenta.';
      final newUid = createdUser.uid;

      final counterRef = _db
          .collection('configuracion')
          .doc('contadores_farmacia');
      final userRef = _db.collection('usuarios').doc(newUid);
      // Reserva técnica por NIT: el ID del documento ES el NIT normalizado.
      // Se crea dentro de la misma transacción que la farmacia y el usuario.
      final nitRef = _db.collection('nits_farmacia').doc(taxId);

      // Transacción: protege tanto el número FARM### como el NIT.
      // En Firestore todas las lecturas deben ocurrir antes de escribir.
      final newPharmacyId = await _db.runTransaction<String>((
        transaction,
      ) async {
        final counterSnapshot = await transaction.get(counterRef);
        final nitSnapshot = await transaction.get(nitRef);
        if (nitSnapshot.exists) {
          throw StateError('Este NIT ya se encuentra registrado en PharmaLab.');
        }
        if (!counterSnapshot.exists) {
          throw StateError('No se configuró el contador de farmacias.');
        }
        final lastNumber = counterSnapshot.data()?['ultimo_numero'];
        if (lastNumber is! int || lastNumber < 0) {
          throw StateError('El contador de farmacias es inválido.');
        }

        final nextNumber = lastNumber + 1;
        final farmId = 'FARM${nextNumber.toString().padLeft(3, '0')}';
        final pharmacyRef = _db.collection('farmacia_cliente').doc(farmId);

        // No incluir aquí telefono ni farmacia_id: esos datos no pertenecen
        // al perfil básico de autenticación y roles.
        transaction.set(userRef, {
          'correo': normalizedEmail,
          'nombre': contact,
          'rol': 'cliente',
          'estado': true,
          'fecha_registro': FieldValue.serverTimestamp(),
        });

        transaction.set(pharmacyRef, {
          'usuario_id': newUid,
          'nombre_farmacia': name,
          'nit': taxId,
          'responsable': contact,
          'telefono': phoneNumber,
          'direccion_fiscal': streetAddress,
          'estado': true,
          'fecha_registro': FieldValue.serverTimestamp(),
        });

        // La operación es atómica: si el NIT está reservado o las reglas
        // rechazan una escritura, no se crea ningún perfil en Firestore.
        transaction.set(nitRef, {'farmacia_id': farmId, 'usuario_id': newUid});
        transaction.update(counterRef, {
          'ultimo_numero': nextNumber,
          'ultimo_id': farmId,
          'ultimo_uid': newUid,
        });
        return farmId;
      });

      final profile = PharmacyProfile(
        commercialName: name,
        nit: taxId,
        responsible: contact,
        phone: phoneNumber,
        address: streetAddress,
        email: normalizedEmail,
      );
      final appUser = AppUser(
        id: newUid,
        name: contact,
        email: normalizedEmail,
        phone: phoneNumber,
        role: UserRole.cliente,
        active: true,
      );

      _currentPharmacy = profile;
      _currentUser = appUser;
      _uid = newUid;
      _pharmacyId = newPharmacyId;
      _accounts[normalizedEmail] = _Account(
        user: appUser,
        pharmacy: profile,
        remote: true,
      );
      _orders.clear();
      completed = true;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (error) {
      return _authError(error);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        // Si alguien reservó el NIT en paralelo, Firestore puede rechazar
        // la segunda escritura con permission-denied (update denegado).
        try {
          final occupied = await _db
              .collection('nits_farmacia')
              .doc(taxId)
              .get(const GetOptions(source: Source.server));
          if (occupied.exists) {
            return 'Este NIT ya se encuentra registrado en PharmaLab.';
          }
        } catch (_) {
          // Mantener el error general si no puede consultarse la reserva.
        }
        return 'Firestore rechazó el registro. Revisa las reglas y el contador.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'No se pudo guardar el registro. Revisa tu conexión.';
      }
      if (error.code == 'aborted') {
        return 'Se están registrando otras farmacias. Inténtalo nuevamente.';
      }
      return 'No se pudo guardar la farmacia (${error.code}).';
    } on StateError catch (error) {
      return error.message.toString();
    } catch (error) {
      debugPrint('Error al registrar farmacia: ${error.runtimeType}');
      return 'Ocurrió un error al crear la cuenta de farmacia.';
    } finally {
      if (!completed) {
        // Auth y Firestore no forman una transacción conjunta. Si Firestore
        // falla, intentamos revertir la cuenta de Auth recién creada.
        if (createdUser != null) {
          try {
            await createdUser.delete();
          } catch (error) {
            debugPrint('No se pudo revertir el usuario Auth: $error');
          }
        }
        _clearSession();
        try {
          await _auth.signOut();
        } catch (error) {
          debugPrint('No se pudo cerrar la sesión tras el error: $error');
        }
        notifyListeners();
      }
    }
  }
}
