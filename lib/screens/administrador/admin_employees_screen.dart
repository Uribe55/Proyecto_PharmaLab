import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../services/employee_repository.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/empty_state.dart';
import 'admin_employee_form_screen.dart';

/// Gestión de empleados con identificadores EMP###.
///
/// Se usa de dos formas:
/// - como pestaña del dashboard ([embedded] = true), sin cabecera propia;
/// - como pantalla independiente con [AdminEmployeesScreen].
class AdminEmployeesPanel extends StatefulWidget {
  const AdminEmployeesPanel({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminEmployeesPanel> createState() => _AdminEmployeesPanelState();
}

class _AdminEmployeesPanelState extends State<AdminEmployeesPanel> {
  final _searchController = TextEditingController();
  late final EmployeeRepository? _repository;
  Stream<List<Employee>>? _stream;
  EmployeePosition? _positionFilter;
  bool? _activeFilter;
  EmployeeCounter? _counter;
  bool _loadingCounter = true;

  bool get _available => PharmaService.instance.usesFirebase;

  @override
  void initState() {
    super.initState();
    if (_available) {
      _repository = EmployeeRepository();
      _stream = _repository!.watchEmployees();
      unawaited(_loadCounter());
    } else {
      _repository = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCounter() async {
    try {
      final counter = await _repository?.readCounter();
      if (!mounted) return;
      setState(() {
        _counter = counter;
        _loadingCounter = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCounter = false);
    }
  }

  Future<void> _openForm([Employee? employee]) async {
    final repository = _repository;
    if (repository == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AdminEmployeeFormScreen(repository: repository, employee: employee),
      ),
    );
    if (saved == true) {
      await _loadCounter();
    }
  }

  Future<void> _toggle(Employee employee) async {
    final repository = _repository;
    if (repository == null) return;
    final next = !employee.estado;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(next ? 'Activar empleado' : 'Desactivar empleado'),
        content: Text(
          next
              ? 'El empleado ${employee.id} podrá volver a iniciar sesión y '
                    'recibir entregas.'
              : 'El empleado ${employee.id} quedará inactivo en empleado y '
                    'usuarios. Sus entregas históricas se conservan. La cuenta '
                    'de Authentication no se elimina.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(next ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final error = await repository.setEmployeeActive(employee, next);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next ? 'Empleado activado.' : 'Empleado desactivado.'),
      ),
    );
  }

  void _openDetail(Employee employee) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _EmployeeDetail(employee: employee),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return _LocalModeNotice(embedded: widget.embedded);
    }
    return StreamBuilder<List<Employee>>(
      stream: _stream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Employee>[];
        final query = _searchController.text.trim().toLowerCase();
        final filtered = all.where((employee) {
          final matchesPosition =
              _positionFilter == null || employee.cargo == _positionFilter;
          final matchesActive =
              _activeFilter == null || employee.estado == _activeFilter;
          final matchesQuery =
              query.isEmpty ||
              employee.id.toLowerCase().contains(query) ||
              employee.nombreCompleto.toLowerCase().contains(query) ||
              employee.correo.toLowerCase().contains(query) ||
              employee.telefono.toLowerCase().contains(query);
          return matchesPosition && matchesActive && matchesQuery;
        }).toList();

        return AdminScrollLayout(
          header: _Filters(
            searchController: _searchController,
            position: _positionFilter,
            active: _activeFilter,
            counter: _counter,
            loadingCounter: _loadingCounter,
            onSearch: () => setState(() {}),
            onPosition: (value) => setState(() => _positionFilter = value),
            onActive: (value) => setState(() => _activeFilter = value),
            onRegister: () => _openForm(),
            onRefreshCounter: _loadCounter,
          ),
          body: AdminScrollList(
            scrollKey: const PageStorageKey('admin-employees-list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ErrorNote(message: '${snapshot.error}'),
                ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Sin empleados en esta vista',
                    description: all.isEmpty
                        ? 'Registra el primer vendedor o repartidor. El '
                              'documento se creará como empleado/EMP###.'
                        : 'No hay empleados que coincidan con la búsqueda '
                              'o los filtros.',
                    action: OutlinedButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _positionFilter = null;
                          _activeFilter = null;
                        });
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                  ),
                )
              else
                for (final employee in filtered) ...[
                  _EmployeeCard(
                    employee: employee,
                    isCurrent:
                        employee.usuarioId ==
                        PharmaService.instance.currentUser?.id,
                    onTap: () => _openForm(employee),
                    onDetail: () => _openDetail(employee),
                    onToggle: () => _toggle(employee),
                  ),
                  if (employee != filtered.last) const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// Pantalla independiente de empleados.
class AdminEmployeesScreen extends StatelessWidget {
  const AdminEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AdminScrollLayout(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTabHeader(title: 'Empleados'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PERSONAL DE PHARMALAB', style: AppText.eyebrow),
                    const SizedBox(height: 4),
                    const Text('Empleados EMP###.', style: AppText.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Vendedores y repartidores con documento propio y '
                      'cuenta de Authentication vinculada.',
                      style: AppText.muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: const AdminEmployeesPanel(),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.position,
    required this.active,
    required this.counter,
    required this.loadingCounter,
    required this.onSearch,
    required this.onPosition,
    required this.onActive,
    required this.onRegister,
    required this.onRefreshCounter,
  });

  final TextEditingController searchController;
  final EmployeePosition? position;
  final bool? active;
  final EmployeeCounter? counter;
  final bool loadingCounter;
  final VoidCallback onSearch;
  final ValueChanged<EmployeePosition?> onPosition;
  final ValueChanged<bool?> onActive;
  final VoidCallback onRegister;
  final VoidCallback onRefreshCounter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CounterBanner(
            counter: counter,
            loading: loadingCounter,
            onRefresh: onRefreshCounter,
            onRegister: onRegister,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onSearch(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por EMP, nombre, correo o teléfono',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.muted,
                    ),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              searchController.clear();
                              onSearch();
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Registrar empleado',
                onPressed: onRegister,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: position == null && active == null,
                  onTap: () {
                    onPosition(null);
                    onActive(null);
                  },
                ),
                const SizedBox(width: 8),
                for (final item in EmployeePosition.values) ...[
                  _FilterChip(
                    label: item.label,
                    selected: position == item,
                    onTap: () => onPosition(position == item ? null : item),
                  ),
                  const SizedBox(width: 8),
                ],
                _FilterChip(
                  label: 'Activos',
                  selected: active == true,
                  onTap: () => onActive(active == true ? null : true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Inactivos',
                  selected: active == false,
                  onTap: () => onActive(active == false ? null : false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterBanner extends StatelessWidget {
  const _CounterBanner({
    required this.counter,
    required this.loading,
    required this.onRefresh,
    required this.onRegister,
  });

  final EmployeeCounter? counter;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final ready = counter != null && counter!.isConsistent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ready ? AppColors.mint : AppColors.pendingBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.pendingText.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.badge_outlined : Icons.warning_amber_rounded,
            size: 18,
            color: ready ? AppColors.primary : AppColors.pendingText,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              ready
                  ? 'Contador listo. El siguiente documento será '
                        'empleado/${counter!.siguienteId}.'
                  : 'Falta o está desincronizado '
                        'configuracion/contadores_empleados. Créalo con '
                        '{ ultimo_numero: 3, ultimo_id: "EMP003" } antes de '
                        'registrar empleados.',
              style: AppText.meta.copyWith(
                fontSize: 10.5,
                color: ready ? AppColors.ink : AppColors.pendingText,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (!ready)
            TextButton(onPressed: onRefresh, child: const Text('Revisar'))
          else
            IconButton(
              tooltip: 'Registrar empleado',
              onPressed: onRegister,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.isCurrent,
    required this.onTap,
    required this.onDetail,
    required this.onToggle,
  });

  final Employee employee;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: employee.estado
                      ? AppColors.mint
                      : AppColors.background,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  employee.iniciales,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: employee.estado
                        ? AppColors.primary
                        : AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          employee.id,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          const Text(
                            'Tú',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      employee.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.correo.isEmpty
                          ? 'Sin correo asociado'
                          : employee.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.meta.copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _MiniChip(
                          label: employee.cargo.label,
                          color: AppColors.primary,
                          background: AppColors.mint,
                        ),
                        _MiniChip(
                          label: employee.estado ? 'Activo' : 'Inactivo',
                          color: employee.estado
                              ? AppColors.successText
                              : AppColors.danger,
                          background: employee.estado
                              ? AppColors.successBackground
                              : AppColors.dangerBackground,
                        ),
                        _MiniChip(
                          label: employee.telefono.isEmpty
                              ? 'Sin teléfono'
                              : employee.telefono,
                          color: AppColors.muted,
                          background: AppColors.background,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Ver detalle',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDetail,
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                  ),
                  IconButton(
                    tooltip: employee.estado ? 'Desactivar' : 'Activar',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggle,
                    icon: Icon(
                      employee.estado
                          ? Icons.toggle_on_rounded
                          : Icons.toggle_off_outlined,
                      size: 21,
                      color: employee.estado
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeDetail extends StatelessWidget {
  const _EmployeeDetail({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final date = employee.fechaIngreso;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(employee.id, style: AppText.h3),
              const Spacer(),
              _MiniChip(
                label: employee.estado ? 'Activo' : 'Inactivo',
                color: employee.estado
                    ? AppColors.successText
                    : AppColors.danger,
                background: employee.estado
                    ? AppColors.successBackground
                    : AppColors.dangerBackground,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(employee.nombreCompleto, style: AppText.h1),
          const SizedBox(height: 12),
          _DetailRow(label: 'Cargo', value: employee.cargo.label),
          _DetailRow(
            label: 'Correo',
            value: employee.correo.isEmpty ? 'Sin correo' : employee.correo,
          ),
          _DetailRow(
            label: 'Teléfono',
            value: employee.telefono.isEmpty
                ? 'Sin teléfono'
                : employee.telefono,
          ),
          _DetailRow(
            label: 'Fecha de ingreso',
            value: date == null
                ? 'Sin fecha registrada'
                : '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/${date.year}',
          ),
          _DetailRow(label: 'UID de Authentication', value: employee.usuarioId),
          const SizedBox(height: 10),
          Text(
            'El documento vive en empleado/${employee.id}. El UID pertenece a '
            'Firebase Authentication y no se puede editar desde la app.',
            style: AppText.meta,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: AppText.meta)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalModeNotice extends StatelessWidget {
  const _LocalModeNotice({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return AdminScrollList(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (!embedded) ...[
          const Text('EMPLEADOS', style: AppText.eyebrow),
          const SizedBox(height: 6),
          const Text('Registro EMP###.', style: AppText.h1),
          const SizedBox(height: 10),
        ],
        EmptyState(
          icon: Icons.badge_outlined,
          title: 'Modo demostración',
          description:
              'El registro de empleados EMP### y su cuenta de Authentication '
              'solo está disponible con Firebase inicializado. En la demo '
              'local puedes probar los roles con las cuentas precargadas.',
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.35,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.5,
          height: 1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Utilidad compartida con la pantalla de usuarios.
String employeeRoleLabel(UserRole role) => switch (role) {
  UserRole.vendedor => EmployeePosition.vendedor.label,
  UserRole.repartidor => EmployeePosition.repartidor.label,
  UserRole.administrador => 'Administrador',
  UserRole.cliente => 'Cliente',
};
