import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/employee.dart';
import '../utils/bolivia_time.dart';
import 'firebase_environment.dart';
import 'pharma_service.dart';

/// Contador `configuracion/contadores_empleados`.
class EmployeeCounter {
  const EmployeeCounter({required this.ultimoNumero, required this.ultimoId});

  final int ultimoNumero;
  final String ultimoId;

  int get siguienteNumero => ultimoNumero + 1;

  String get siguienteId => EmployeeRepository.code(siguienteNumero);

  bool get isConsistent => ultimoId == EmployeeRepository.code(ultimoNumero);
}

/// Resultado del alta de un empleado.
///
/// Firebase Authentication y Firestore no comparten una transacción atómica.
/// Si Auth se creó pero Firestore falló, [authCreated] es `true`, [uid] contiene
/// la cuenta creada y [employeeId] queda nulo. La UI nunca debe mostrar éxito en
/// ese caso: debe ofrecer completar el perfil.
class EmployeeRegistrationResult {
  const EmployeeRegistrationResult({
    this.employeeId,
    this.uid,
    this.error,
    this.authCreated = false,
  });

  final String? employeeId;
  final String? uid;
  final String? error;
  final bool authCreated;

  bool get success => employeeId != null && error == null;

  bool get partial => authCreated && employeeId == null;

  String get message {
    if (success) return 'Empleado $employeeId registrado correctamente.';
    return error ?? 'No se pudo registrar el empleado.';
  }
}

/// Acceso a `empleado`, `usuarios` y al contador de empleados.
///
/// Solo opera contra Firebase real/emulador. En modo local la UI muestra los
/// datos de demostración y no permite escribir documentos EMP###.
class EmployeeRepository {
  EmployeeRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    PharmaService? service,
  }) : _db = db ?? FirebaseEnvironment.firestore,
       _auth = auth ?? FirebaseEnvironment.auth,
       _service = service ?? PharmaService.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final PharmaService _service;
  final _pendingDrafts = <String, EmployeeDraft>{};

  bool get isAvailable => _service.usesFirebase;

  static String code(int number) {
    if (number < 10) return 'EMP00$number';
    if (number < 100) return 'EMP0$number';
    return 'EMP$number';
  }

  DocumentReference<Map<String, dynamic>> get _counterRef =>
      _db.collection('configuracion').doc('contadores_empleados');

  /// Lee el contador. Devuelve `null` si todavía no fue creado manualmente.
  Future<EmployeeCounter?> readCounter() async {
    final snapshot = await _counterRef.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists) return null;
    final data = snapshot.data() ?? const <String, dynamic>{};
    final number = data['ultimo_numero'];
    final id = data['ultimo_id'];
    if (number is! int || id is! String) return null;
    return EmployeeCounter(ultimoNumero: number, ultimoId: id);
  }

  /// Empleados con el correo asociado desde `usuarios/{usuario_id}`.
  Stream<List<Employee>> watchEmployees() {
    final controller = StreamController<List<Employee>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? employeeSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? userSub;
    var employees = <Employee>[];
    var users = <String, Map<String, dynamic>>{};
    var closed = false;

    void emit() {
      if (closed) return;
      final list = [
        for (final employee in employees)
          employee.copyWith(
            correo:
                (users[employee.usuarioId]?['correo'] ??
                        users[employee.usuarioId]?['email'] ??
                        '')
                    .toString(),
          ),
      ]..sort((a, b) => a.id.compareTo(b.id));
      controller.add(list);
    }

    controller.onListen = () {
      employeeSub = _db
          .collection('empleado')
          .snapshots()
          .listen(
            (snapshot) {
              employees = snapshot.docs
                  .map(
                    (doc) =>
                        Employee.fromMap(doc.id, _employeeData(doc.data())),
                  )
                  .whereType<Employee>()
                  .toList();
              emit();
            },
            onError: (Object error) {
              if (closed) return;
              controller.addError(
                'No se pudieron cargar los empleados. Revisa las reglas y la '
                'conexión.',
              );
              debugPrint('Error al escuchar empleados: ${error.runtimeType}');
            },
          );
      userSub = _db
          .collection('usuarios')
          .snapshots()
          .listen(
            (snapshot) {
              users = {for (final doc in snapshot.docs) doc.id: doc.data()};
              emit();
            },
            onError: (Object error) {
              // El listado de empleados sigue siendo útil sin el correo.
              debugPrint('Error al escuchar usuarios para empleados: $error');
            },
          );
    };

    controller.onCancel = () async {
      closed = true;
      await employeeSub?.cancel();
      await userSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Verifica el contador y el siguiente ID antes de crear la cuenta de Auth.
  ///
  /// Esto evita dejar cuentas huérfanas en Authentication cuando falta el
  /// documento de contadores o está desincronizado.
  Future<String?> preflight(EmployeeCounter? counter) async {
    if (!isAvailable) {
      return 'El registro de empleados requiere Firebase.';
    }
    if (counter == null) {
      return 'Falta crear manualmente configuracion/contadores_empleados con '
          '{ ultimo_numero: 3, ultimo_id: "EMP003" }.';
    }
    if (!counter.isConsistent) {
      return 'El contador está desincronizado: ultimo_id no coincide con '
          'ultimo_numero. Corrígelo en la consola antes de registrar.';
    }
    final nextId = counter.siguienteId;
    final exists = await _db
        .collection('empleado')
        .doc(nextId)
        .get(const GetOptions(source: Source.server));
    if (exists.exists) {
      return 'El documento empleado/$nextId ya existe. Actualiza el contador '
          'antes de continuar.';
    }
    return null;
  }

  /// Registra un empleado completo.
  ///
  /// 1. Verifica el contador (sin escribir nada).
  /// 2. Crea la cuenta en una instancia secundaria de Firebase Auth para no
  ///    cerrar la sesión del administrador.
  /// 3. En una transacción de Firestore crea `empleado/EMP###`,
  ///    `usuarios/{uid}` y actualiza el contador.
  ///
  /// Si el paso 3 falla, la cuenta de Auth se conserva y se devuelve
  /// [EmployeeRegistrationResult.partial] con el UID para completar el perfil.
  Future<EmployeeRegistrationResult> registerEmployee({
    required EmployeeDraft draft,
    required String password,
  }) async {
    final validation = draft.validate();
    if (validation != null) {
      return EmployeeRegistrationResult(error: validation);
    }
    if (password.length < 6) {
      return const EmployeeRegistrationResult(
        error: 'La contraseña temporal debe tener al menos 6 caracteres.',
      );
    }
    if (_auth.currentUser == null ||
        _service.currentUser?.role != UserRole.administrador ||
        _service.currentUser?.active != true) {
      return const EmployeeRegistrationResult(
        error: 'Solo un administrador activo puede registrar empleados.',
      );
    }

    EmployeeCounter? counter;
    String? preflightError;
    try {
      counter = await readCounter();
      preflightError = await preflight(counter);
    } catch (error) {
      debugPrint('No se pudo leer el contador de empleados: $error');
      return const EmployeeRegistrationResult(
        error:
            'No se pudo leer configuracion/contadores_empleados. Revisa la '
            'conexión y las reglas antes de reintentar.',
      );
    }
    if (preflightError != null) {
      return EmployeeRegistrationResult(error: preflightError);
    }

    final email = draft.correo.trim().toLowerCase();
    try {
      final existing = await _db
          .collection('usuarios')
          .where('correo', isEqualTo: email)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existing.docs.isNotEmpty) {
        return const EmployeeRegistrationResult(
          error: 'Ya existe un perfil con ese correo electrónico.',
        );
      }
    } on FirebaseException catch (error) {
      // Si la consulta falla se deja que Authentication valide el correo.
      debugPrint('No se pudo verificar el correo previo: ${error.code}');
    }

    final access = await _service.createStaffAccess(email, password);
    if (access.error != null || access.uid == null) {
      return EmployeeRegistrationResult(
        error: access.error ?? 'Falta el UID de Authentication.',
      );
    }
    final uid = access.uid!;
    _pendingDrafts[uid] = draft;
    try {
      final employeeId = await _provision(draft: draft, uid: uid);
      return EmployeeRegistrationResult(
        employeeId: employeeId,
        uid: uid,
        authCreated: true,
      );
    } on FirebaseException catch (error) {
      return EmployeeRegistrationResult(
        uid: uid,
        authCreated: true,
        error:
            'La cuenta de Authentication se creó (UID $uid), pero Firestore '
            'rechazó el perfil (${error.code}). No se muestra éxito. Corrige el '
            'error y usa "Completar perfil pendiente".',
      );
    } catch (error) {
      debugPrint('Error al provisionar el empleado: $error');
      return EmployeeRegistrationResult(
        uid: uid,
        authCreated: true,
        error:
            'La cuenta de Authentication se creó (UID $uid), pero no se pudo '
            'guardar el perfil en Firestore. Usa "Completar perfil pendiente".',
      );
    }
  }

  /// Completa el perfil de una cuenta de Auth que quedó sin documentos.
  Future<EmployeeRegistrationResult> completePendingRegistration({
    required String uid,
    required EmployeeDraft draft,
  }) async {
    final verifiedDraft = _pendingDrafts[uid];
    if (verifiedDraft == null) {
      return EmployeeRegistrationResult(
        uid: uid,
        error: 'Reabre el alta con el correo y contraseña originales para verificar el UID.',
      );
    }
    draft = verifiedDraft;
    final validation = draft.validate();
    if (validation != null) {
      return EmployeeRegistrationResult(error: validation, uid: uid);
    }
    if (_service.currentUser?.role != UserRole.administrador ||
        _service.currentUser?.active != true) {
      return EmployeeRegistrationResult(
        uid: uid,
        error: 'Solo un administrador activo puede completar perfiles.',
      );
    }

    try {
      final existing = await _db
          .collection('empleado')
          .where('usuario_id', isEqualTo: uid)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (existing.docs.isNotEmpty) {
        final profile = await _db
            .collection('usuarios')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        final employee = existing.docs.first.data();
        if (profile.data()?['empleado_id'] != existing.docs.first.id ||
            profile.data()?['estado'] != employee['estado'] ||
            profile.data()?['rol'] !=
                (employee['cargo'] == 'Vendedor' ? 'vendedor' : 'repartidor')) {
          return EmployeeRegistrationResult(
            uid: uid,
            error: 'El vínculo existente es inconsistente; requiere revisión manual.',
          );
        }
        return EmployeeRegistrationResult(
          employeeId: existing.docs.first.id,
          uid: uid,
          authCreated: true,
        );
      }
      final employeeId = await _provision(draft: draft, uid: uid);
      return EmployeeRegistrationResult(
        employeeId: employeeId,
        uid: uid,
        authCreated: true,
      );
    } on FirebaseException catch (error) {
      return EmployeeRegistrationResult(
        uid: uid,
        authCreated: true,
        error: 'No se pudo completar el perfil (${error.code}).',
      );
    } catch (error) {
      debugPrint('Error al completar el perfil: $error');
      return EmployeeRegistrationResult(
        uid: uid,
        authCreated: true,
        error: 'No se pudo completar el perfil pendiente.',
      );
    }
  }

  Future<String> _provision({required EmployeeDraft draft, required String uid}) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final before = await readCounter();
      try {
        return await _provisionOnce(draft: draft, uid: uid);
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' || attempt == 3) rethrow;
        // Some emulator/client combinations report a rules rejection before
        // an optimistic conflict. Retry only if another registration advanced.
        final after = await readCounter();
        if (before == null || after == null || after.ultimoNumero <= before.ultimoNumero) rethrow;
      }
    }
    throw StateError('No se pudo reservar el consecutivo.');
  }

  Future<String> _provisionOnce({
    required EmployeeDraft draft,
    required String uid,
  }) async {
    return _db.runTransaction<String>((transaction) async {
      final counterSnapshot = await transaction.get(_counterRef);
      if (!counterSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Falta el contador de empleados.',
        );
      }
      final counterData = counterSnapshot.data()!;
      final last = counterData['ultimo_numero'];
      final lastId = counterData['ultimo_id'];
      if (last is! int || lastId is! String || lastId != code(last)) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'El contador de empleados está desincronizado.',
        );
      }
      final next = last + 1;
      final employeeId = code(next);
      final employeeRef = _db.collection('empleado').doc(employeeId);
      final userRef = _db.collection('usuarios').doc(uid);
      final employeeSnapshot = await transaction.get(employeeRef);
      if (employeeSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'El documento $employeeId ya existe.',
        );
      }
      final userSnapshot = await transaction.get(userRef);

      transaction.set(
        employeeRef,
        draft.employeeMap(
          usuarioId: uid,
          fechaIngreso: FieldValue.serverTimestamp(),
        ),
      );
      if (userSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'already-exists',
          message: 'El UID ya tiene perfil.',
        );
      }
      transaction.set(
        userRef,
        draft.userMap(
          empleadoId: employeeId,
          fechaRegistro: FieldValue.serverTimestamp(),
        ),
      );
      transaction.update(_counterRef, {
        'ultimo_numero': next,
        'ultimo_id': employeeId,
      });
      return employeeId;
    });
  }

  /// Edita nombre, apellido, teléfono, cargo y estado.
  ///
  /// El ID EMP### y el `usuario_id` son inmutables. El estado se replica en
  /// `usuarios/{uid}` dentro de la misma transacción.
  Future<String?> updateEmployee(Employee employee) async {
    if (!isAvailable) return 'La edición requiere Firebase.';
    if (_service.currentUser?.role != UserRole.administrador ||
        _service.currentUser?.active != true) {
      return 'Solo un administrador activo puede editar empleados.';
    }
    if (!employee.estado && _service.currentUser?.id == employee.usuarioId) {
      return 'No puedes desactivar tu propia cuenta.';
    }
    try {
      await _db.runTransaction<void>((transaction) async {
        final employeeRef = _db.collection('empleado').doc(employee.id);
        final userRef = _db.collection('usuarios').doc(employee.usuarioId);
        final employeeSnapshot = await transaction.get(employeeRef);
        final userSnapshot = await transaction.get(userRef);
        if (!employeeSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'El empleado ya no existe.',
          );
        }
        if (!userSnapshot.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'not-found',
            message: 'El perfil de usuario del empleado no existe.',
          );
        }
        transaction.update(employeeRef, employee.toUpdateMap());
        transaction.update(userRef, {
          'nombre': employee.nombreCompleto,
          'telefono': employee.telefono.trim(),
          'rol': employee.cargo.role,
          'estado': employee.estado,
          'empleado_id': employee.id,
        });
      });
      return null;
    } on FirebaseException catch (error) {
      return _friendlyWriteError(error);
    } catch (error) {
      debugPrint('Error al actualizar empleado: $error');
      return 'No se pudo actualizar el empleado.';
    }
  }

  /// Activa o desactiva el acceso del empleado en `empleado` y `usuarios`.
  Future<String?> setEmployeeActive(Employee employee, bool active) async {
    if (!isAvailable) return 'La gestión de empleados requiere Firebase.';
    if (!active && _service.currentUser?.id == employee.usuarioId) {
      return 'No puedes desactivar tu propia cuenta.';
    }
    return updateEmployee(employee.copyWith(estado: active));
  }

  /// Convierte los `Timestamp` de Firestore a `DateTime` para el modelo.
  Map<String, dynamic> _employeeData(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    for (final key in const ['fecha_ingreso', 'fecha_registro']) {
      final value = copy[key];
      if (value is Timestamp) copy[key] = value.toDate();
    }
    return copy;
  }

  String _friendlyWriteError(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'Firestore denegó la operación. Verifica que tu usuario siga siendo '
            'administrador activo y que las reglas estén publicadas.',
      'not-found' => 'El documento del empleado o su perfil ya no existe.',
      'failed-precondition' =>
        'El contador de empleados falta o está desincronizado.',
      'already-exists' => 'El identificador EMP### ya está ocupado.',
      _ => 'No se pudo guardar el empleado (${error.code}).',
    };
  }

  /// Fecha de ingreso normalizada a hora de Bolivia para la UI.
  static DateTime? boliviaDate(Object? value) {
    if (value is Timestamp) return BoliviaTime.fromInstant(value.toDate());
    if (value is DateTime) return BoliviaTime.fromInstant(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed == null ? null : BoliviaTime.fromInstant(parsed);
    }
    return null;
  }
}
