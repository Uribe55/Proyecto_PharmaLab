/// Roles definidos en el RNF-02 del proyecto.
enum UserRole {
  cliente(
    'Cliente',
    'Catálogo, carrito, pedidos',
    'Consulta el catálogo, arma pedidos y hace seguimiento de sus compras.',
  ),
  vendedor(
    'Vendedor',
    'Revisión, aprobación y asignación',
    'Revisa pedidos pendientes, aprueba y asigna entregas a un repartidor.',
  ),
  repartidor(
    'Repartidor',
    'Entregas e incidencias',
    'Consulta solo sus entregas asignadas y registra la entrega o la incidencia.',
  ),
  administrador(
    'Administrador',
    'Usuarios, permisos y supervisión',
    'Gestiona usuarios y roles, y supervisa pedidos, entregas y reportes.',
  );

  const UserRole(this.label, this.summary, this.description);

  final String label;
  final String summary;
  final String description;

  bool get isEmployee => this != UserRole.cliente;

  /// Permisos principales tomados de la tabla de actores del informe.
  List<String> get permissions {
    return switch (this) {
      UserRole.cliente => const [
        'Ver catálogo y precios de venta',
        'Crear pedidos y consultar su estado',
        'Consultar su propio historial',
        'Descargar el resumen del pedido',
      ],
      UserRole.vendedor => const [
        'Ver todos los pedidos pendientes y aprobados',
        'Aprobar pedidos verificando stock y datos',
        'Asignar entregas a repartidores',
        'Consultar catálogo y stock',
      ],
      UserRole.repartidor => const [
        'Ver solo sus entregas asignadas',
        'Marcar un pedido como entregado',
        'Registrar una entrega fallida',
        'Trabajar sin conexión y sincronizar al volver',
      ],
      UserRole.administrador => const [
        'Crear, editar y desactivar usuarios',
        'Asignar roles y permisos',
        'Supervisar pedidos y entregas',
        'Respaldar y exportar la información',
      ],
    };
  }
}

/// Usuario del sistema: clientes, vendedores, repartidores y administradores.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.active = true,
    this.address = '',
    this.tieneDeudaVencida = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool active;

  /// Dirección de entrega editable por el cliente y el repartidor (RF-01).
  final String address;

  /// Estado de cuenta simulado: Firestore aún no registra facturación real.
  /// Cuando es `true`, el checkout bloquea la confirmación (RF-07).
  final bool tieneDeudaVencida;

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'usuario';
    return parts.first;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PL';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  /// Dominio interno que corresponde a cada rol según la convención de
  /// correos del sistema: nombre + inicial del apellido + dominio.
  static const Map<UserRole, String> employeeDomains = {
    UserRole.vendedor: 'ven',
    UserRole.repartidor: 'rep',
    UserRole.administrador: 'admin',
  };

  static const String _accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  static const String _plain = 'aaaaaeeeeiiiiooooouuuunc';

  static String _withoutAccents(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final index = _accents.indexOf(character);
      buffer.write(index == -1 ? character : _plain[index]);
    }
    return buffer.toString();
  }

  /// Genera el correo institucional de un empleado.
  ///
  /// Ejemplos: `Ana Vargas` + vendedor → `anav@ven.pharma.com`,
  /// `Carlos Mendoza` + repartidor → `carlosm@rep.pharma.com` y
  /// `Laura Rojas` + administrador → `laurar@admin.pharma.com`.
  /// Devuelve `null` para el rol cliente, que usa el correo de su farmacia.
  static String? employeeEmail(String name, UserRole role) {
    final domain = employeeDomains[role];
    if (domain == null) return null;

    final normalized = _withoutAccents(name.trim().toLowerCase());
    final parts = normalized
        .split(RegExp(r'[^a-z]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    final firstName = parts.first;
    final lastInitial = parts.length > 1 ? parts.last[0] : '';
    return '$firstName$lastInitial@$domain.pharma.com';
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? active,
    String? address,
    bool? tieneDeudaVencida,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      active: active ?? this.active,
      address: address ?? this.address,
      tieneDeudaVencida: tieneDeudaVencida ?? this.tieneDeudaVencida,
    );
  }
}
