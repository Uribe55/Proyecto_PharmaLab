import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/pharma_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/admin_scroll_layout.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_avatar.dart';
import 'admin_employees_screen.dart';
import 'admin_user_form_screen.dart';

/// Gestión de usuarios y roles (RF-19).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  UserRole? _roleFilter;

  @override
  void initState() {
    super.initState();
    // Refresca la lista con los perfiles de `usuarios` en Firestore (RF-19).
    unawaited(PharmaService.instance.refreshUsers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openForm([AppUser? user]) {
    if (PharmaService.instance.usesFirebase &&
        (user == null ||
            user.role == UserRole.vendedor ||
            user.role == UserRole.repartidor)) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AdminEmployeesScreen()));
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AdminUserFormScreen(user: user)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PharmaService.instance,
      builder: (context, _) {
        final all = PharmaService.instance.users;
        final query = _searchController.text.trim().toLowerCase();
        final users = all.where((user) {
          final matchesRole = _roleFilter == null || user.role == _roleFilter;
          final matchesQuery =
              query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
          return matchesRole && matchesQuery;
        }).toList();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
            label: const Text(
              'Nuevo usuario',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: AdminScrollList(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    headerPrefix: const AppTabHeader(
                      title: 'Gestión de usuarios',
                    ),
                    headerChildren: [
                      const Text('CUENTAS Y PERMISOS', style: AppText.eyebrow),
                      const SizedBox(height: 7),
                      const Text('Usuarios del sistema.', style: AppText.h1),
                      const SizedBox(height: 6),
                      const Text(
                        'Crea, edita y desactiva cuentas. Cada rol accede solo '
                        'a las funciones que le corresponden.',
                        style: AppText.muted,
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminEmployeesScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Gestionar empleados EMP###'),
                      ),
                      const SizedBox(height: 12),
                      if (PharmaService.instance.loadingUsers)
                        const LinearProgressIndicator(),
                      if (PharmaService.instance.usersError != null)
                        Text(
                          PharmaService.instance.usersError!,
                          style: AppText.muted,
                        ),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o correo',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.muted,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.muted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'Todos',
                              selected: _roleFilter == null,
                              onTap: () => setState(() => _roleFilter = null),
                            ),
                            for (final role in UserRole.values) ...[
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: role.label,
                                selected: _roleFilter == role,
                                onTap: () => setState(() => _roleFilter = role),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Cuentas', style: AppText.h3),
                          ),
                          Text(
                            '${users.length} '
                            '${users.length == 1 ? 'resultado' : 'resultados'}',
                            style: AppText.meta,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (users.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: EmptyState(
                            icon: Icons.manage_accounts_outlined,
                            title: 'Sin usuarios en esta vista',
                            description:
                                'No hay cuentas que coincidan con la '
                                'búsqueda o el rol seleccionado.',
                            action: OutlinedButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _roleFilter = null);
                              },
                              child: const Text('Limpiar filtros'),
                            ),
                          ),
                        )
                      else
                        for (final user in users) ...[
                          _UserCard(
                            user: user,
                            isCurrent:
                                user.id ==
                                PharmaService.instance.currentUser?.id,
                            onTap: () => _openForm(user),
                          ),
                          if (user != users.last) const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrent,
    required this.onTap,
  });

  final AppUser user;
  final bool isCurrent;
  final VoidCallback onTap;

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
              UserAvatar(size: 42, user: user),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Tú',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
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
                          label: user.role.label,
                          color: AppColors.primary,
                          background: AppColors.mint,
                        ),
                        _MiniChip(
                          label: user.active ? 'Activo' : 'Inactivo',
                          color: user.active
                              ? AppColors.successText
                              : AppColors.danger,
                          background: user.active
                              ? AppColors.successBackground
                              : AppColors.dangerBackground,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
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
