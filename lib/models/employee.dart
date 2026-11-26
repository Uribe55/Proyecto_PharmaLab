/// Cargo del empleado dentro de PharmaLab.
///
/// El valor [label] es exactamente el que ya existe en la colección
/// `empleado` (`Vendedor` / `Repartidor`). El valor [role] es el que se guarda
/// en `usuarios.rol` para Firebase Authentication/Firestore.
enum EmployeePosition {
  vendedor('Vendedor', 'vendedor'),
  repartidor('Repartidor', 'repartidor');

  const EmployeePosition(this.label, this.role);

  final String label;
  final String role;

  static EmployeePosition? fromCargo(String? cargo) {
    final normalized = (cargo ?? '').trim().toLowerCase();
    return switch (normalized) {
      'vendedor' || 'seller' => EmployeePosition.vendedor,
      'repartidor' || 'driver' => EmployeePosition.repartidor,
      _ => null,
    };
  }

  static EmployeePosition? fromRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return switch (normalized) {
      'vendedor' => EmployeePosition.vendedor,
      'repartidor' => EmployeePosition.repartidor,
      _ => null,
    };
  }
}

/// Documento `empleado/EMP###`.
///
/// El identificador del documento es el código EMP###; el UID real de Firebase
/// Authentication se guarda en `usuario_id`. El correo no se escribe en
/// `empleado`: se obtiene del perfil `usuarios/{usuario_id}`.
class Employee {
  const Employee({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.cargo,
    required this.telefono,
    required this.estado,
    required this.usuarioId,
    this.fechaIngreso,
    this.correo = '',
  });

  final String id;
  final String nombre;
  final String apellido;
  final EmployeePosition cargo;
  final String telefono;
  final bool estado;
  final String usuarioId;
  final DateTime? fechaIngreso;
  final String correo;

  String get nombreCompleto =>
      [nombre.trim(), apellido.trim()].where((part) => part.isNotEmpty).join(' ');

  String get iniciales {
    final first = nombre.trim();
    final last = apellido.trim();
    if (first.isEmpty && last.isEmpty) return 'EMP';
    final a = first.isEmpty ? '' : first[0];
    final b = last.isEmpty ? '' : last[0];
    return '$a$b'.toUpperCase();
  }

  Employee copyWith({
    String? nombre,
    String? apellido,
    EmployeePosition? cargo,
    String? telefono,
    bool? estado,
    String? correo,
  }) {
    return Employee(
      id: id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      cargo: cargo ?? this.cargo,
      telefono: telefono ?? this.telefono,
      estado: estado ?? this.estado,
      usuarioId: usuarioId,
      fechaIngreso: fechaIngreso,
      correo: correo ?? this.correo,
    );
  }

  /// Datos tal como se guardan en `empleado/EMP###`.
  ///
  /// `fechaIngreso` no se incluye en las actualizaciones para conservar la
  /// fecha original; en el alta se envía `FieldValue.serverTimestamp()`.
  Map<String, dynamic> toCreateMap({required Object fechaIngreso}) {
    return {
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'cargo': cargo.label,
      'telefono': telefono.trim(),
      'estado': estado,
      'fecha_ingreso': fechaIngreso,
      'usuario_id': usuarioId,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'cargo': cargo.label,
      'telefono': telefono.trim(),
      'estado': estado,
    };
  }

  static Employee? fromMap(
    String id,
    Map<String, dynamic> data, {
    String correo = '',
  }) {
    final position = EmployeePosition.fromCargo(
      _text(data, const ['cargo', 'posicion', 'puesto']),
    );
    final usuarioId = _text(data, const ['usuario_id', 'uid', 'user_id']);
    if (position == null || usuarioId.isEmpty) return null;
    return Employee(
      id: id,
      nombre: _text(data, const ['nombre', 'nombres']),
      apellido: _text(data, const ['apellido', 'apellidos']),
      cargo: position,
      telefono: _text(data, const ['telefono', 'celular', 'phone']),
      estado: _bool(data['estado'] ?? data['activo']) ?? true,
      usuarioId: usuarioId,
      fechaIngreso: _date(data['fecha_ingreso'] ?? data['fecha_registro']),
      correo: correo,
    );
  }

  static String _text(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
    }
    return '';
  }

  static bool? _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 'activo' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == 'inactivo' ||
          normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    // Se evita importar cloud_firestore en el modelo: los Timestamp llegan al
    // repositorio, que ya los convierte antes de construir el empleado.
    return null;
  }
}

/// Datos validados para registrar o completar un empleado.
class EmployeeDraft {
  const EmployeeDraft({
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.cargo,
    this.estado = true,
  });

  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final EmployeePosition cargo;
  final bool estado;

  String get nombreCompleto => '$nombre $apellido'.trim();

  String? validate() {
    if (nombre.trim().isEmpty) return 'Ingresa el nombre del empleado.';
    if (apellido.trim().isEmpty) return 'Ingresa el apellido del empleado.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo.trim())) {
      return 'Ingresa un correo electrónico válido.';
    }
    if (telefono.trim().isEmpty) return 'Ingresa un teléfono de contacto.';
    return null;
  }

  /// Mapa de `empleado/EMP###` para el alta dentro de una transacción.
  Map<String, dynamic> employeeMap({
    required String usuarioId,
    required Object fechaIngreso,
  }) {
    return {
      'nombre': nombre.trim(),
      'apellido': apellido.trim(),
      'cargo': cargo.label,
      'telefono': telefono.trim(),
      'estado': estado,
      'fecha_ingreso': fechaIngreso,
      'usuario_id': usuarioId,
    };
  }

  /// Mapa de `usuarios/{uid}` para el alta dentro de una transacción.
  Map<String, dynamic> userMap({
    required String empleadoId,
    required Object fechaRegistro,
  }) {
    return {
      'nombre': nombreCompleto,
      'correo': correo.trim().toLowerCase(),
      'telefono': telefono.trim(),
      'rol': cargo.role,
      'estado': estado,
      'fecha_registro': fechaRegistro,
      'empleado_id': empleadoId,
    };
  }
}
